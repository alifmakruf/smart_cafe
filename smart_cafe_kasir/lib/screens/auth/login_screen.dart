import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/meja_provider.dart';
import '../../providers/kartu_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../services/api_service.dart';
import '../home_screen.dart';
import '../../widget/connection_test_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFCA968A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.coffee,
                      size: 64,
                      color: Color(0xFF81422E),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Warung Kopi',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Management System',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Server Info Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _showServerSettingsDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.dns, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${settingsProvider.serverIp}:${settingsProvider.serverPort}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.settings, color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showConnectionTest(settingsProvider.baseUrl),
                        icon: const Icon(Icons.network_check, color: Colors.white),
                        tooltip: 'Test Connection',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D4C41),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Nama Field
                        TextFormField(
                          controller: _namaController,
                          decoration: InputDecoration(
                            labelText: 'Nama',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama harus diisi';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password harus diisi';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCA968A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Default Credentials Info

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerSettingsDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    final ipController = TextEditingController(text: settingsProvider.serverIp);
    final portController = TextEditingController(text: settingsProvider.serverPort);
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4C41).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dns, color: Color(0xFF6D4C41), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Server Settings'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current URL Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settingsProvider.baseUrl,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.100',
                    prefixIcon: const Icon(Icons.computer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !isTesting,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: portController,
                  decoration: InputDecoration(
                    labelText: 'Port',
                    hintText: '8000',
                    prefixIcon: const Icon(Icons.settings_ethernet),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !isTesting,
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.help_outline, size: 18, color: Colors.orange[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pastikan HP dan Server terhubung ke WiFi yang sama',
                          style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                setDialogState(() => isTesting = true);

                try {
                  await settingsProvider.saveSettings('10.147.116.211', '8000');
                  ipController.text = '10.147.116.211';
                  portController.text = '8000';

                  // ✅ UPDATE ALL PROVIDERS
                  if (context.mounted) {
                    final newApi = ApiService(baseUrl: settingsProvider.baseUrl);
                    context.read<AuthProvider>().initialize(newApi);
                    context.read<MenuProvider>().initialize(newApi);
                    context.read<MejaProvider>().initialize(newApi);
                    context.read<KartuProvider>().initialize(newApi);
                    context.read<PesananProvider>().initialize(newApi);

                    print('✅ All providers updated with: ${settingsProvider.baseUrl}');
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Reset ke default'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } finally {
                  setDialogState(() => isTesting = false);
                }
              },
              child: const Text('Reset'),
            ),
            ElevatedButton.icon(
              onPressed: isTesting
                  ? null
                  : () async {
                final ip = ipController.text.trim();
                final port = portController.text.trim();

                if (ip.isEmpty || port.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('IP dan Port harus diisi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => isTesting = true);

                try {
                  // Test connection
                  final testUrl = 'http://$ip:$port/api/v1';
                  final api = ApiService(baseUrl: testUrl);

                  print('\n🔍 Testing connection to: $testUrl');
                  final isConnected = await api.testConnection();

                  if (!isConnected) {
                    throw Exception('Tidak dapat terhubung ke server');
                  }

                  // Save settings
                  await settingsProvider.saveSettings(ip, port);
                  print('✅ Settings saved: ${settingsProvider.baseUrl}');

                  // ✅ UPDATE ALL PROVIDERS WITH NEW API
                  if (context.mounted) {
                    final newApi = ApiService(baseUrl: settingsProvider.baseUrl);

                    print('🔄 Updating all providers...');
                    context.read<AuthProvider>().initialize(newApi);
                    context.read<MenuProvider>().initialize(newApi);
                    context.read<MejaProvider>().initialize(newApi);
                    context.read<KartuProvider>().initialize(newApi);
                    context.read<PesananProvider>().initialize(newApi);

                    print('✅ All providers updated!');
                    print('   New base URL: ${settingsProvider.baseUrl}');
                  }

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('✓ Server berhasil terhubung'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              settingsProvider.baseUrl,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('❌ Connection error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Error: $e')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } finally {
                  setDialogState(() => isTesting = false);
                }
              },
              icon: isTesting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check, size: 18),
              label: Text(isTesting ? 'Testing...' : 'Test & Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4C41),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      await authProvider.login(
        _namaController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showConnectionTest(String baseUrl) {
    showDialog(
      context: context,
      builder: (context) => ConnectionTestDialog(baseUrl: baseUrl),
    );
  }
}