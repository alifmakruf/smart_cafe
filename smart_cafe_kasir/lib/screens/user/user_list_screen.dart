import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  ApiService _getApiService() {
    final settingsProvider = context.read<SettingsProvider>();
    return ApiService(baseUrl: settingsProvider.baseUrl);
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = _getApiService();
      print('📡 Fetching users from: ${api.baseUrl}');

      final data = await api.getUsers();

      setState(() {
        _users = data.map((json) => User.fromJson(json)).toList();
        _isLoading = false;
      });

      print('✅ Loaded ${_users.length} users');
    } catch (e) {
      print('❌ Error fetching users: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kelola Users'),
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada user',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4C41),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchUsers,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final isCurrentUser = user.id == authProvider.currentUser?.id;

            Color roleColor = Colors.blue;
            IconData roleIcon = Icons.person;

            switch (user.posisi) {
              case 'admin':
                roleColor = Colors.red;
                roleIcon = Icons.admin_panel_settings;
                break;
              case 'kasir':
                roleColor = Colors.green;
                roleIcon = Icons.point_of_sale;
                break;
              case 'kitchen':
                roleColor = Colors.orange;
                roleIcon = Icons.restaurant;
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(roleIcon, color: roleColor),
                ),
                title: Row(
                  children: [
                    Text(
                      user.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.posisiDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: user.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'password':
                        _showChangePasswordDialog(user);
                        break;
                      case 'toggle_status':
                        _toggleUserStatus(user);
                        break;
                      case 'delete':
                        if (!isCurrentUser) {
                          _showDeleteConfirmation(user);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'password',
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 20),
                          SizedBox(width: 12),
                          Text('Ubah Password'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive ? Icons.block : Icons.check_circle,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(user.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                        ],
                      ),
                    ),
                    if (!isCurrentUser)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah User'),
      ),
    );
  }

  void _showAddUserDialog() {
    final namaController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedPosisi = 'kasir';
    bool isSubmitting = false; // ✅ Track submit state

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah User Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !isSubmitting, // ✅ Disable saat submit
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPosisi,
                decoration: const InputDecoration(
                  labelText: 'Posisi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: const [
                  DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: isSubmitting
                    ? null // ✅ Disable saat submit
                    : (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedPosisi = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                enabled: !isSubmitting, // ✅ Disable saat submit
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                if (namaController.text.isEmpty || passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semua field harus diisi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // ✅ Set submitting state
                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  final api = _getApiService();
                  await api.register(
                    namaController.text,
                    selectedPosisi,
                    passwordController.text,
                  );

                  if (mounted) {
                    Navigator.pop(dialogContext); // ✅ Close dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('✓ User berhasil ditambahkan'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchUsers(); // ✅ Refresh list
                  }
                } catch (e) {
                  // ✅ Reset submitting state on error
                  setDialogState(() {
                    isSubmitting = false;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4C41),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(User user) {
    final passwordController = TextEditingController();
    bool isSubmitting = false; // ✅ Track submit state

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Ubah Password: ${user.nama}'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password Baru',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            enabled: !isSubmitting,
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                if (passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password minimal 6 karakter'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isSubmitting = true;
                });

                try {
                  final api = _getApiService();
                  await api.changePassword(user.id, passwordController.text);

                  if (mounted) {
                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('✓ Password berhasil diubah'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isSubmitting = false;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4C41),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Ubah'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(User user) async {
    // ✅ Show inline loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Memproses...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final api = _getApiService();
      await api.updateUser(user.id, {'is_active': !user.isActive});

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✓ User ${user.isActive ? 'dinonaktifkan' : 'diaktifkan'}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus User'),
        content: Text('Yakin ingin menghapus user ${user.nama}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // ✅ Show inline loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Menghapus user...'),
                    ],
                  ),
                  duration: Duration(seconds: 30),
                ),
              );

              try {
                final api = _getApiService();
                await api.deleteUser(user.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('✓ User berhasil dihapus'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchUsers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}