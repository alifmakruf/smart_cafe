import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pesanan.dart';
import '../../providers/meja_provider.dart';
import '../../providers/pesanan_provider.dart';

class PilihMejaScreen extends StatefulWidget {
  final Pesanan pesanan;

  const PilihMejaScreen({Key? key, required this.pesanan}) : super(key: key);

  @override
  State<PilihMejaScreen> createState() => _PilihMejaScreenState();
}

class _PilihMejaScreenState extends State<PilihMejaScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<MejaProvider>().fetchMejas());
  }

  @override
  Widget build(BuildContext context) {
    final mejaProvider = context.watch<MejaProvider>();

    // Filter meja yang terisi (ada customer)
    final mejaTerisi = mejaProvider.mejas
        .where((m) => m.status == 'terisi')
        .toList();

    return PopScope(
      canPop: true, // ✅ Allow back button
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Pilih Meja Customer'),
          backgroundColor: const Color(0xFF6D4C41),
          foregroundColor: Colors.white,
          // ✅ Back button otomatis ada
        ),
        body: mejaProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : mejaTerisi.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Tidak ada meja yang terisi',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              const Text(
                'Semua customer sudah selesai atau\nbelum ada yang order',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        )
            : Column(
          children: [
            // Info Pesanan
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.blue, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesanan Tambahan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.pesanan.nomorPesanan,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Rp ${widget.pesanan.totalHarga.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6D4C41),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pilih meja customer yang mau order lagi',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Daftar Meja Terisi
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: mejaTerisi.length,
                itemBuilder: (context, index) {
                  final meja = mejaTerisi[index];

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _confirmAssignMeja(context, meja.id!, meja.nomorMeja),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade400,
                              Colors.orange.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.table_restaurant,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Meja ${meja.nomorMeja}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TERISI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAssignMeja(BuildContext context, int mejaId, int nomorMeja) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Meja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant, size: 64, color: Colors.orange.shade600),
            const SizedBox(height: 16),
            Text(
              'Tambahkan pesanan ke Meja $nomorMeja?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.pesanan.nomorPesanan,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _assignMeja(context, mejaId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  // ✅ FIX: assignMeja method di pesanan_provider.dart

  // Di pilih_meja_screen.dart, tambahkan ini:
  Future<void> _assignMeja(BuildContext context, int mejaId) async {
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
                  Text('Menambahkan pesanan...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // ✅ ADD DETAILED LOGGING
      print('\n🔧 === ASSIGN MEJA DEBUG ===');
      print('Pesanan ID: ${widget.pesanan.id}');
      print('Meja ID: $mejaId');
      print('Pesanan Status: ${widget.pesanan.status}');
      print('Pesanan Items: ${widget.pesanan.items}');
      print('================================\n');

      await context.read<PesananProvider>().assignMeja(
        widget.pesanan.id!,
        mejaId,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Pesanan ${widget.pesanan.nomorPesanan} berhasil ditambahkan!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.of(context).pop();

    } catch (e, stackTrace) {
      print('\n❌ === ASSIGN MEJA ERROR ===');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('================================\n');

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 4),
              const Text(
                'Cek terminal untuk detail lengkap',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}