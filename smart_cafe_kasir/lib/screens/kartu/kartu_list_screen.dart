import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/kartu_provider.dart';
import '../../models/kartu.dart';

class KartuListScreen extends StatefulWidget {
  const KartuListScreen({Key? key}) : super(key: key);

  @override
  State<KartuListScreen> createState() => _KartuListScreenState();
}

class _KartuListScreenState extends State<KartuListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<KartuProvider>().fetchKartus());
  }

  @override
  Widget build(BuildContext context) {
    final kartuProvider = context.watch<KartuProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kartu RFID'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: kartuProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kartuProvider.kartus.length,
        itemBuilder: (context, index) {
          final kartu = kartuProvider.kartus[index];
          final isAvailable = kartu.status == 'available';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isAvailable ? null : Colors.grey.shade200,
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${kartu.status}',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (kartu.lastUsedAt != null)
                    Text(
                      'Terakhir digunakan: ${DateFormat('dd/MM/yyyy HH:mm').format(kartu.lastUsedAt!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, kartu),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddKartuDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kartu'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddKartuDialog(BuildContext context) {
    final uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kartu RFID'),
        content: TextField(
          controller: uidController,
          decoration: const InputDecoration(
            labelText: 'UID Kartu',
            hintText: 'Contoh: aabbccdd',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = uidController.text.trim();
              if (uid.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('UID tidak boleh kosong')),
                );
                return;
              }

              try {
                final kartu = Kartu(uid: uid);
                await context.read<KartuProvider>().addKartu(kartu);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kartu berhasil ditambahkan')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Kartu kartu) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kartu'),
        content: Text('Yakin hapus kartu dengan UID ${kartu.uid}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<KartuProvider>().deleteKartu(kartu.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kartu berhasil dihapus')),
                  );
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
