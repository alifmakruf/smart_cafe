import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/menu_provider.dart';
import '../../models/menu.dart';
import 'menu_form_screen.dart';

class MenuListScreen extends StatefulWidget {
  const MenuListScreen({Key? key}) : super(key: key);

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<MenuProvider>().fetchMenus());
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Menu'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: menuProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuProvider.menus.length,
        itemBuilder: (context, index) {
          final menu = menuProvider.menus[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.brown.withOpacity(0.2),
                child: const Icon(Icons.restaurant_menu, color: Colors.brown),
              ),
              title: Text(
                menu.nama,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currencyFormat.format(menu.harga)),
                  if (menu.kategori != null)
                    Text('Kategori: ${menu.kategori}'),
                  Text('Stok: ${menu.stok}'),
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
                        builder: (_) => MenuFormScreen(menu: menu),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context, menu);
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
            MaterialPageRoute(builder: (_) => const MenuFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Menu menu) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Menu'),
        content: Text('Yakin hapus menu "${menu.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<MenuProvider>().deleteMenu(menu.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menu berhasil dihapus')),
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
