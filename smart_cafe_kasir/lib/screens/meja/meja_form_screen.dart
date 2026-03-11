import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/meja_provider.dart';
import '../../models/meja.dart';

class MejaFormScreen extends StatefulWidget {
  final Meja? meja;

  const MejaFormScreen({Key? key, this.meja}) : super(key: key);

  @override
  State<MejaFormScreen> createState() => _MejaFormScreenState();
}

class _MejaFormScreenState extends State<MejaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomorMejaController;
  late TextEditingController _kapasitasController;
  late TextEditingController _esp8266IdController;
  String _selectedStatus = 'kosong';

  @override
  void initState() {
    super.initState();
    _nomorMejaController = TextEditingController(
      text: widget.meja?.nomorMeja.toString() ?? '',
    );
    _kapasitasController = TextEditingController(
      text: widget.meja?.kapasitas.toString() ?? '4',
    );
    _esp8266IdController = TextEditingController(
      text: widget.meja?.esp8266Id ?? '',
    );
    _selectedStatus = widget.meja?.status ?? 'kosong';
  }

  @override
  void dispose() {
    _nomorMejaController.dispose();
    _kapasitasController.dispose();
    _esp8266IdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.meja != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Meja' : 'Tambah Meja'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomorMejaController,
              decoration: const InputDecoration(
                labelText: 'Nomor Meja',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nomor meja tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kapasitasController,
              decoration: const InputDecoration(
                labelText: 'Kapasitas (orang)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kapasitas tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _esp8266IdController,
              decoration: const InputDecoration(
                labelText: 'ESP8266 ID (opsional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.memory),
                hintText: 'esp8266_meja_1',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: const [
                DropdownMenuItem(value: 'kosong', child: Text('Kosong')),
                DropdownMenuItem(value: 'terisi', child: Text('Terisi')),
                DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
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
              child: Text(isEdit ? 'Update Meja' : 'Tambah Meja'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final meja = Meja(
        id: widget.meja?.id,
        nomorMeja: int.parse(_nomorMejaController.text),
        kapasitas: int.parse(_kapasitasController.text),
        status: _selectedStatus,
        esp8266Id: _esp8266IdController.text.isEmpty
            ? null
            : _esp8266IdController.text,
      );

      try {
        if (widget.meja == null) {
          await context.read<MejaProvider>().addMeja(meja);
        } else {
          await context.read<MejaProvider>().updateMeja(widget.meja!.id!, meja);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.meja == null
                  ? 'Meja berhasil ditambahkan'
                  : 'Meja berhasil diupdate'),
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
