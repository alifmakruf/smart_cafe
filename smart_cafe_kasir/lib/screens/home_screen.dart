import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// Providers
import '../providers/auth_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/meja_provider.dart';
import '../providers/kartu_provider.dart';
import '../providers/pesanan_provider.dart';

// Screens Kasir
import 'pesanan/create_pesanan_screen.dart';
import 'pesanan/antrian_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'kartu/deactivate_card_screen.dart';
import 'pesanan/history_screen.dart';

// Screens Admin
import 'menu/menu_list_screen.dart';
import 'meja/meja_list_screen.dart';
import 'kartu/kartu_list_screen.dart';
import 'settings/settings_screen.dart';
import 'user/user_list_screen.dart';

// Auth
import 'auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // ✅ INITIAL FETCH (with loading indicator)
    Future.microtask(() {
      _refreshAllData();
    });

    // ✅ AUTO REFRESH every 10 seconds (SILENT - no loading)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _silentRefresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ✅ INITIAL REFRESH (with loading indicator)
  void _refreshAllData() {
    context.read<MenuProvider>().fetchMenus();
    context.read<MejaProvider>().fetchMejas();
    context.read<KartuProvider>().fetchKartus();
    context.read<PesananProvider>().fetchPesanans();
  }

  // ✅ SILENT REFRESH (background update, no loading spinner)
  void _silentRefresh() {
    context.read<MenuProvider>().fetchMenusSilent();
    context.read<MejaProvider>().fetchMejasSilent();
    context.read<KartuProvider>().fetchKartusSilent();
    context.read<PesananProvider>().fetchPesanansSilent();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    List<NavigationItem> navItems = _getNavigationItems(user.posisi);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warung Kopi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${user.nama} • ${user.posisiDisplay}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6D4C41),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: navItems.map((item) => item.screen).toList(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF6D4C41),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: navItems
              .map(
                (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems(String posisi) {
    switch (posisi) {
      case 'kasir':
        return [
          NavigationItem(
              icon: Icons.add_shopping_cart,
              label: 'Buat Pesanan',
              screen: const CreatePesananScreen()),
          NavigationItem(
              icon: Icons.list_alt,
              label: 'Antrian',
              screen: const AntrianScreen()),
          NavigationItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              screen: const DashboardScreen()),
          NavigationItem(
              icon: Icons.credit_card_off,
              label: 'Selesaikan',
              screen: const DeactivateCardScreen()),
          NavigationItem(
              icon: Icons.history,
              label: 'Riwayat',
              screen: const HistoryScreen()),
        ];

      case 'kitchen':
        return [
          NavigationItem(
              icon: Icons.list_alt,
              label: 'Antrian',
              screen: const AntrianScreen()),
          NavigationItem(
              icon: Icons.history,
              label: 'Riwayat',
              screen: const HistoryScreen()),
        ];

      case 'admin':
        return [
          NavigationItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              screen: const DashboardScreen()),
          NavigationItem(
              icon: Icons.restaurant_menu,
              label: 'Menu',
              screen: const MenuListScreen()),
          NavigationItem(
              icon: Icons.table_restaurant,
              label: 'Meja',
              screen: const MejaListScreen()),
          NavigationItem(
              icon: Icons.credit_card,
              label: 'Kartu',
              screen: const KartuListScreen()),
          NavigationItem(
              icon: Icons.people,
              label: 'Users',
              screen: const UserListScreen()),
          NavigationItem(
              icon: Icons.settings,
              label: 'Settings',
              screen: const SettingsScreen()),
        ];

      default:
        return [
          NavigationItem(
              icon: Icons.error,
              label: 'Error',
              screen: const Center(child: Text('Invalid Role'))),
        ];
    }
  }

  // ✅ LOGOUT (clear stack properly)
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => PopScope(
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
                            Text('Logging out...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              try {
                await context.read<AuthProvider>().logout();

                if (context.mounted) {
                  Navigator.of(context).pop(); // close loading
                  // ✅ Clear entire navigation stack
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
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
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ✅ EXIT APP (proper dialog)
  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi'),
        content: const Text('Yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}