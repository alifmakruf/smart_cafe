import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/kartu_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../services/nfc_service.dart';

class DeactivateCardScreen extends StatefulWidget {
  const DeactivateCardScreen({Key? key}) : super(key: key);

  @override
  State<DeactivateCardScreen> createState() => _DeactivateCardScreenState();
}

class _DeactivateCardScreenState extends State<DeactivateCardScreen> {
  final NfcService _nfc = NfcService();
  String? _scannedUid;
  bool _isWaitingForCard = false;
  bool _isProcessing = false;
  StreamSubscription? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _initNfc();
  }

  Future<void> _initNfc() async {
    print('Initializing NFC for card deactivation...');

    bool available = await _nfc.checkAvailability();

    if (available) {
      print('✓ NFC Available');

      _nfcSubscription = _nfc.nfcStream.listen((uid) {
        print('NFC Card detected: $uid');

        if (mounted && !_isProcessing) {
          setState(() {
            _scannedUid = uid;
            _isWaitingForCard = false;
          });

          // Auto process
          _deactivateCard(uid);
        }
      });
    } else {
      print('✗ NFC Not Available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC tidak tersedia di device ini'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    if (_nfc.isScanning) {
      _nfc.stopScanning();
    }
    _nfc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_nfc.isScanning) {
          await _nfc.stopScanning();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Selesaikan Pesanan'),
          backgroundColor: Color(0xFF6D4C41),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6D4C41)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Memproses...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else if (_isWaitingForCard)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc,
                              size: 100,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Tempelkan Kartu',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tempelkan kartu customer ke belakang HP untuk menyelesaikan pesanan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _nfc.stopScanning();
                              setState(() {
                                _isWaitingForCard = false;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Batal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Color(0xFF6D4C41).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc,
                              size: 100,
                              color: Color(0xFF6D4C41),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Selesaikan Pesanan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap kartu customer untuk menyelesaikan pesanan dan menonaktifkan kartu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blue, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  'Setelah tap kartu:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Pesanan akan diselesaikan\n• Kartu kembali tersedia\n• Meja akan kosong\n• Relay meja akan OFF',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[800],
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () async {
                              setState(() {
                                _isWaitingForCard = true;
                                _scannedUid = null;
                              });
                              await _nfc.startScanning();
                            },
                            icon: const Icon(Icons.nfc),
                            label: const Text('Mulai Scan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6D4C41),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 20,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deactivateCard(String uid) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _nfc.stopScanning();
      await context.read<PesananProvider>().deactivateCard(uid);

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 64, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pesanan Selesai!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Kartu telah dinonaktifkan',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6D4C41),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // ✅ Reset state (stay on this screen, ready for next scan)
      setState(() {
        _isProcessing = false;
        _isWaitingForCard = false;
        _scannedUid = null;
      });
    } catch (e) {
      print('Error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isProcessing = false;
        _isWaitingForCard = false;
      });
    }
  }
}