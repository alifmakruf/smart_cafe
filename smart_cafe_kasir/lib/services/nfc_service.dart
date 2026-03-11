import 'dart:async';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  final StreamController<String> _nfcController = StreamController<String>.broadcast();
  Stream<String> get nfcStream => _nfcController.stream;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Future<bool> checkAvailability() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      _isAvailable = availability == NFCAvailability.available;
      print('NFC Available: $_isAvailable');
      return _isAvailable;
    } catch (e) {
      print('Error checking NFC: $e');
      _isAvailable = false;
      return false;
    }
  }

  Future<void> startScanning() async {
    if (!_isAvailable) {
      print('NFC not available');
      return;
    }

    if (_isScanning) {
      print('Already scanning');
      return;
    }

    try {
      _isScanning = true;
      print('Starting NFC scan...');

      // Poll for NFC tag
      var tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: 60),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Scan your card",
      );

      print('\n=== NFC Tag Detected ===');
      print('Tag Type: ${tag.type}');
      print('Tag ID: ${tag.id}');

      String uid = tag.id.toUpperCase();
      print('Card UID: $uid');

      _nfcController.add(uid);

      // Stop scanning
      await stopScanning();

    } catch (e) {
      print('Error during NFC scan: $e');
      _isScanning = false;
      await stopScanning();
    }
  }

  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      print('Stopping NFC scan...');
      await FlutterNfcKit.finish();
      _isScanning = false;
      print('NFC scan stopped');
    } catch (e) {
      print('Error stopping NFC scan: $e');
      _isScanning = false;
    }
  }

  void dispose() {
    stopScanning();
    _nfcController.close();
  }
}