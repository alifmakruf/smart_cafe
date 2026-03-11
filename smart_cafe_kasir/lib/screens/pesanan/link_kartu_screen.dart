import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/pesanan.dart';
import '../../providers/kartu_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../services/nfc_service.dart';

class LinkKartuScreen extends StatefulWidget {
  final Pesanan pesanan;

  const LinkKartuScreen({Key? key, required this.pesanan}) : super(key: key);

  @override
  State<LinkKartuScreen> createState() => _LinkKartuScreenState();
}

class _LinkKartuScreenState extends State<LinkKartuScreen> {
  final NfcService _nfc = NfcService();
  String? _scannedUid;
  bool _isWaitingForCard = false;
  StreamSubscription? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _initNfc();
    Future.microtask(() => context.read<KartuProvider>().fetchKartus());
  }

  Future<void> _initNfc() async {
    print('Initializing NFC...');

    bool available = await _nfc.checkAvailability();

    if (available) {
      print('✓ NFC Available');

      _nfcSubscription = _nfc.nfcStream.listen((uid) {
        print('NFC Card detected: $uid');

        if (mounted) {
          setState(() {
            _scannedUid = uid;
            _isWaitingForCard = false;
          });
        }
      });
    } else {
      print('✗ NFC Not Available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC tidak tersedia. Gunakan pilihan manual.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    print('Disposing LinkKartuScreen...');
    _nfcSubscription?.cancel();
    if (_nfc.isScanning) {
      _nfc.stopScanning();
    }
    _nfc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kartuProvider = context.watch<KartuProvider>();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        // ✅ Stop NFC saat back
        if (_nfc.isScanning) {
          await _nfc.stopScanning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Link Kartu RFID'),
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
          // ✅ Tombol back sudah ada otomatis
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Info Pesanan
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'Pesanan: ${widget.pesanan.nomorPesanan}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: Rp ${widget.pesanan.totalHarga.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section: Scan NFC
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nfc, color: Colors.green, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Metode 1: Scan Kartu NFC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isWaitingForCard)
                        Column(
                          children: [
                            const SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                strokeWidth: 6,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tempelkan kartu ke belakang HP...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pastikan NFC HP sudah aktif',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () async {
                                await _nfc.stopScanning();
                                setState(() {
                                  _isWaitingForCard = false;
                                });
                              },
                              child: const Text('Batal'),
                            ),
                          ],
                        )
                      else if (_scannedUid != null)
                        Column(
                          children: [
                            const Icon(Icons.check_circle, size: 64, color: Colors.green),
                            const SizedBox(height: 12),
                            const Text(
                              'Kartu berhasil terbaca!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'UID: $_scannedUid',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _linkKartu(_scannedUid!),
                              icon: const Icon(Icons.link),
                              label: const Text('Konfirmasi Link Kartu'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _scannedUid = null;
                                });
                              },
                              child: const Text('Scan Ulang'),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const Icon(Icons.nfc, size: 80, color: Colors.green),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _nfc.isAvailable
                                  ? () async {
                                setState(() {
                                  _isWaitingForCard = true;
                                  _scannedUid = null;
                                });
                                await _nfc.startScanning();
                              }
                                  : null,
                              icon: const Icon(Icons.nfc),
                              label: Text(
                                _nfc.isAvailable
                                    ? 'Mulai Scan Kartu NFC'
                                    : 'NFC Tidak Tersedia',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                            ),
                            if (!_nfc.isAvailable)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Gunakan metode manual di bawah',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 16),

              // Section: Pilih Manual
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list, color: Colors.brown),
                  SizedBox(width: 8),
                  Text(
                    'Metode 2: Pilih Kartu Manual',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: kartuProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : kartuProvider.kartus.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card_off,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Tidak ada kartu terdaftar'),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: kartuProvider.kartus.length,
                  itemBuilder: (context, index) {
                    final kartu = kartuProvider.kartus[index];
                    final isAvailable = kartu.status == 'available';

                    return Card(
                      color: isAvailable ? null : Colors.grey.shade300,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAvailable
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          child: Icon(
                            isAvailable ? Icons.check_circle : Icons.block,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          'UID: ${kartu.uid}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${kartu.status}',
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                        ),
                        trailing: isAvailable
                            ? const Icon(Icons.arrow_forward_ios, size: 16)
                            : null,
                        enabled: isAvailable,
                        onTap: isAvailable ? () => _linkKartu(kartu.uid) : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _linkKartu(String uid) async {
    print('\n=== LINK KARTU START ===');

    // Stop NFC
    if (_nfc.isScanning) {
      await _nfc.stopScanning();
    }

    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menghubungkan kartu...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      await context.read<PesananProvider>().linkKartu(
        widget.pesanan.id!,
        uid,
      );

      if (!mounted) return;

      // Close loading
      Navigator.of(context).pop();

      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('✓ Kartu berhasil di-link!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Wait briefly for user to see the message
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // ✅ FIX: Pop back to CreatePesananScreen (bukan ke Home)
      Navigator.of(context).pop();

    } catch (e) {
      print('ERROR: $e');

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}