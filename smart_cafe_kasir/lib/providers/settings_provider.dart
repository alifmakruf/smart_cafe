import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _serverIp = '10.241.29.112';
  String _serverPort = '8000';

  String get serverIp => _serverIp;
  String get serverPort => _serverPort;
  String get baseUrl => 'http://$_serverIp:$_serverPort/api/v1';

  /// Load settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIp = prefs.getString('server_ip') ?? '10.241.29.112';
      _serverPort = prefs.getString('server_port') ?? '8000';

      print('✓ Settings loaded: $_serverIp:$_serverPort');
      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> saveSettings(String ip, String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', ip);
      await prefs.setString('server_port', port);

      _serverIp = ip;
      _serverPort = port;

      print('✓ Settings saved: $_serverIp:$_serverPort');
      notifyListeners();
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  /// Reset to default
  Future<void> resetToDefault() async {
    await saveSettings('10.241.29.112', '8000');
  }

  /// Update IP only
  void updateIp(String ip) {
    _serverIp = ip;
    notifyListeners();
  }

  /// Update Port only
  void updatePort(String port) {
    _serverPort = port;
    notifyListeners();
  }
}