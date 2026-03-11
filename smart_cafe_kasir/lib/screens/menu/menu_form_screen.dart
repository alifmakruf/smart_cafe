import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/menu_provider.dart';
import '../../models/menu.dart';

class MenuFormScreen extends StatefulWidget {
  final Menu? menu;

  const MenuFormScreen({Key? key, this.menu}) : super(key: key);

  @override
  State<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends State<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _hargaController;
  late TextEditingController _kategoriController;
  late TextEditingController _stokController;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.menu?.nama ?? '');
    _hargaController = TextEditingController(
      text: widget.menu?.harga.toString() ?? '',
    );
    _kategoriController = TextEditingController(text: widget.menu?.kategori ?? '');
    _stokController = TextEditingController(
      text: widget.menu?.stok.toString() ?? '999',
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    _kategoriController.dispose();
    _stokController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.menu != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Menu' : 'Tambah Menu'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Menu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama menu tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hargaController,
              decoration: const InputDecoration(
                labelText: 'Harga',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Harga tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kategoriController,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                hintText: 'Minuman, Makanan, Snack',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stokController,
              decoration: const InputDecoration(
                labelText: 'Stok',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Stok tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: Text(isEdit ? 'Update Menu' : 'Tambah Menu'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final menu = Menu(
        id: widget.menu?.id,
        nama: _namaController.text,
        harga: double.parse(_hargaController.text),
        kategori: _kategoriController.text.isEmpty ? null : _kategoriController.text,
        stok: int.parse(_stokController.text),
      );

      try {
        if (widget.menu == null) {
          await context.read<MenuProvider>().addMenu(menu);
        } else {
          await context.read<MenuProvider>().updateMenu(widget.menu!.id!, menu);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.menu == null
                  ? 'Menu berhasil ditambahkan'
                  : 'Menu berhasil diupdate'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}