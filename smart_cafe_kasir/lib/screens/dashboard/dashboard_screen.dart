import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/meja_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../models/pesanan.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<MejaProvider>().fetchMejas(),
      context.read<PesananProvider>().fetchPesanans(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mejaProvider = context.watch<MejaProvider>();
    final pesananProvider = context.watch<PesananProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Meja'),
        backgroundColor: Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: mejaProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: mejaProvider.mejas.length,
          itemBuilder: (context, index) {
            final meja = mejaProvider.mejas[index];

            // ✅ FIX: Find active order safely (no error if not found)
            Pesanan? activePesanan;
            try {
              activePesanan = pesananProvider.pesanans.firstWhere(
                    (p) => p.mejaId == meja.id &&
                    ['preparing', 'ready', 'placed'].contains(p.status),
              );
            } catch (e) {
              // No active order found - that's OK
              activePesanan = null;
            }

            final hasActiveOrder = activePesanan != null;

            Color cardColor = Colors.white;
            Color borderColor = Colors.grey;
            IconData icon = Icons.event_available;
            String statusText = 'Kosong';

            if (meja.status == 'terisi') {
              cardColor = Colors.red.shade50;
              borderColor = Colors.red;
              icon = Icons.event_busy;
              statusText = 'Terisi';
            } else if (meja.status == 'reserved') {
              cardColor = Colors.orange.shade50;
              borderColor = Colors.orange;
              icon = Icons.event_note;
              statusText = 'Reserved';
            } else {
              cardColor = Colors.green.shade50;
              borderColor = Colors.green;
            }

            return Card(
              elevation: 4,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 2),
              ),
              child: InkWell(
                onTap: () => _showMejaDetail(context, meja, activePesanan),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 48, color: borderColor),
                      const SizedBox(height: 12),
                      Text(
                        'Meja ${meja.nomorMeja}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasActiveOrder) ...[
                        const SizedBox(height: 8),
                        Text(
                          activePesanan!.nomorPesanan,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showMejaDetail(BuildContext context, meja, Pesanan? pesanan) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  meja.status == 'terisi'
                      ? Icons.event_busy
                      : Icons.event_available,
                  size: 32,
                  color: meja.status == 'terisi' ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 16),
                Text(
                  'Meja ${meja.nomorMeja}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Kapasitas', '${meja.kapasitas} orang'),
            _buildInfoRow('Status', meja.status),
            if (meja.esp8266Id != null)
              _buildInfoRow('ESP8266 ID', meja.esp8266Id!),
            if (pesanan != null) ...[
              const Divider(height: 32),
              const Text(
                'Pesanan Aktif:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Nomor', pesanan.nomorPesanan),
              _buildInfoRow('Status', pesanan.status.toUpperCase()),
              _buildInfoRow('Total', 'Rp ${pesanan.totalHarga.toStringAsFixed(0)}'),
            ],
            const SizedBox(height: 16),
            if (meja.status == 'terisi')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmResetMeja(context, meja);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Reset Meja (Manual)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _confirmResetMeja(BuildContext context, meja) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Meja'),
        content: Text('Yakin ingin reset Meja ${meja.nomorMeja} secara manual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<MejaProvider>().updateStatus(meja.id!, 'kosong');
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meja berhasil direset')),
                  );
                  // Refresh after reset
                  await _refreshData();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}