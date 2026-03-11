import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/meja_provider.dart';
import '../../models/meja.dart';
import 'meja_form_screen.dart';

class MejaListScreen extends StatefulWidget {
  const MejaListScreen({Key? key}) : super(key: key);

  @override
  State<MejaListScreen> createState() => _MejaListScreenState();
}

class _MejaListScreenState extends State<MejaListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<MejaProvider>().fetchMejas());
  }

  @override
  Widget build(BuildContext context) {
    final mejaProvider = context.watch<MejaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Meja'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: mejaProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mejaProvider.mejas.length,
        itemBuilder: (context, index) {
          final meja = mejaProvider.mejas[index];

          Color statusColor = Colors.grey;
          IconData statusIcon = Icons.check_circle;

          if (meja.status == 'kosong') {
            statusColor = Colors.green;
            statusIcon = Icons.event_available;
          } else if (meja.status == 'terisi') {
            statusColor = Colors.red;
            statusIcon = Icons.event_busy;
          } else if (meja.status == 'reserved') {
            statusColor = Colors.orange;
            statusIcon = Icons.event_note;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.2),
                child: Icon(statusIcon, color: statusColor),
              ),
              title: Text(
                'Meja ${meja.nomorMeja}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kapasitas: ${meja.kapasitas} orang'),
                  Text(
                    'Status: ${meja.status}',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
                  ),
                  if (meja.esp8266Id != null)
                    Text('ESP ID: ${meja.esp8266Id}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MejaFormScreen(meja: meja),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context, meja);
                  }
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MejaFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Meja'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Meja meja) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Meja'),
        content: Text('Yakin hapus Meja ${meja.nomorMeja}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<MejaProvider>().deleteMeja(meja.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meja berhasil dihapus')),
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
