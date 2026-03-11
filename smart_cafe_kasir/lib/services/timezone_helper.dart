// File: lib/services/timezone_helper.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class TimezoneHelper {
  static final TimezoneHelper _instance = TimezoneHelper._internal();
  factory TimezoneHelper() => _instance;
  TimezoneHelper._internal();

  // Cache offset untuk menghindari request berulang
  Duration? _serverOffset;
  DateTime? _lastSync;

  /// Get server time offset (perbedaan antara server UTC dan device local)
  Future<Duration> getServerOffset(String serverUrl) async {
    try {
      // Jika sudah sync dalam 1 jam terakhir, gunakan cache
      if (_serverOffset != null && _lastSync != null) {
        final timeSinceSync = DateTime.now().difference(_lastSync!);
        if (timeSinceSync.inMinutes < 60) {
          print('✅ Using cached server offset: $_serverOffset');
          return _serverOffset!;
        }
      }

      print('\n🌐 ========== SYNCING WITH SERVER TIME ==========');

      // Get device time
      final deviceNow = DateTime.now();
      print('📱 Device Local Time: $deviceNow');
      print('📱 Device Timezone: ${deviceNow.timeZoneName} (${deviceNow.timeZoneOffset})');

      // Request ke server
      final stopwatch = Stopwatch()..start();
      final response = await http.get(
        Uri.parse('$serverUrl/time'),
      ).timeout(const Duration(seconds: 5));

      final latency = stopwatch.elapsedMilliseconds ~/ 2; // Round-trip / 2

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Server mengirim timestamp UTC
        final serverUtcString = data['utc'] ?? data['timestamp'];
        final serverUtc = DateTime.parse(serverUtcString).toUtc();

        // Kompensasi network latency
        final serverUtcAdjusted = serverUtc.add(Duration(milliseconds: latency));

        print('🌍 Server UTC Time: $serverUtcAdjusted');
        print('⏱️  Network Latency: ${latency}ms');

        // Hitung offset antara server UTC dan device local
        final deviceLocal = DateTime.now();
        final deviceUtc = deviceLocal.toUtc();

        _serverOffset = serverUtcAdjusted.difference(deviceUtc);
        _lastSync = DateTime.now();

        print('📊 Device UTC: $deviceUtc');
        print('📊 Server UTC: $serverUtcAdjusted');
        print('📊 Calculated Offset: $_serverOffset');
        print('================================================\n');

        return _serverOffset!;
      }
    } catch (e) {
      print('⚠️  Failed to sync with server time: $e');
      print('⚠️  Using device time as fallback');
    }

    // Fallback: no offset
    return Duration.zero;
  }

  /// Parse datetime dari server (assume UTC) ke local timezone yang benar
  DateTime parseServerDateTime(String? dateString, {Duration? serverOffset}) {
    if (dateString == null || dateString.isEmpty) {
      return DateTime.now();
    }

    try {
      // Parse datetime
      DateTime parsed;
      if (dateString.contains('T')) {
        // ISO 8601 format
        parsed = DateTime.parse(dateString);
      } else if (dateString.contains(' ')) {
        // SQL format
        parsed = DateTime.parse(dateString.replaceAll(' ', 'T'));
      } else {
        parsed = DateTime.parse(dateString);
      }

      // CRITICAL: Treat as UTC dari server
      DateTime utcTime;
      if (parsed.isUtc) {
        utcTime = parsed;
      } else {
        // Jika tidak ada timezone info, assume UTC
        utcTime = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }

      // Apply server offset jika ada
      if (serverOffset != null && serverOffset != Duration.zero) {
        utcTime = utcTime.add(serverOffset);
      }

      // Convert ke local timezone device
      final localTime = utcTime.toLocal();

      return localTime;

    } catch (e) {
      print('❌ Error parsing datetime: $e');
      return DateTime.now();
    }
  }

  /// Clear cache (untuk force resync)
  void clearCache() {
    _serverOffset = null;
    _lastSync = null;
    print('🗑️  Server time cache cleared');
  }
}