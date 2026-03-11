import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Services
import 'services/api_service.dart';
import 'services/mqtt_service.dart';

// Providers
import 'providers/menu_provider.dart';
import 'providers/meja_provider.dart';
import 'providers/kartu_provider.dart';
import 'providers/pesanan_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => MejaProvider()),
        ChangeNotifierProvider(create: (_) => KartuProvider()),
        ChangeNotifierProvider(create: (_) => PesananProvider()),
      ],
      child: const AppInitializer(),
    );
  }
}

// ✅ Separate widget to prevent rebuild loop
class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('\n🚀 ========== APP INITIALIZING ==========');

      // Load settings first
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.loadSettings();

      print('✓ Settings loaded: ${settingsProvider.serverIp}:${settingsProvider.serverPort}');
      print('✓ Base URL: ${settingsProvider.baseUrl}');

      // Initialize API Service with loaded settings
      final api = ApiService(baseUrl: settingsProvider.baseUrl);

      // Initialize all providers with API
      context.read<AuthProvider>().initialize(api);
      context.read<MenuProvider>().initialize(api);
      context.read<MejaProvider>().initialize(api);
      context.read<KartuProvider>().initialize(api);
      context.read<PesananProvider>().initialize(api);

      print('✓ All providers initialized');
      print('========== INITIALIZATION COMPLETE ==========\n');

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Initialization error: $e');
      setState(() {
        _isInitialized = true; // Continue anyway
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFFCA968A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Initializing...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ PENTING: MaterialApp HARUS DI SINI, BUKAN DI LUAR MultiProvider!
    return MaterialApp(
      title: 'Warung Kopi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // ✅ MQTT connect NON-BLOCKING (background)
    _connectMqttInBackground();

    // Try to load saved session
    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.loadSession();

    if (!mounted) return;

    // Navigate based on auth status
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasSession ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  // ✅ MQTT connection running in background
  void _connectMqttInBackground() {
    print('🔄 Initializing MQTT in background...');
    final mqtt = MqttService();
    mqtt.connect().then((success) {
      if (success) {
        print('✅ MQTT connected successfully');
      } else {
        print('⚠️ MQTT connection failed (app will still work)');
      }
    }).catchError((error) {
      print('❌ MQTT error: $error (app will still work)');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCA968A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
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
                size: 80,
                color: Color(0xFF7A3119),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Warung Kopi',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Management System',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


