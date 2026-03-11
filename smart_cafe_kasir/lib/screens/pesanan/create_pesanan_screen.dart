import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/menu_provider.dart';
import '../../providers/meja_provider.dart';
import '../../providers/pesanan_provider.dart';
import 'link_kartu_screen.dart';
import 'pilih_meja_screen.dart';

class CreatePesananScreen extends StatefulWidget {
  const CreatePesananScreen({Key? key}) : super(key: key);

  @override
  State<CreatePesananScreen> createState() => _CreatePesananScreenState();
}

class _CreatePesananScreenState extends State<CreatePesananScreen>
    with SingleTickerProviderStateMixin {
  final currencyFormat = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      context.read<MenuProvider>().fetchMenus();
      context.read<MejaProvider>().fetchMejas();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final pesananProvider = context.watch<PesananProvider>();

    final makananList = menuProvider.menus
        .where((m) =>
    m.kategori?.toLowerCase() == 'makanan' ||
        m.kategori?.toLowerCase() == 'food')
        .toList();

    final minumanList = menuProvider.menus
        .where((m) =>
    m.kategori?.toLowerCase() == 'minuman' ||
        m.kategori?.toLowerCase() == 'drink' ||
        m.kategori?.toLowerCase() == 'beverage')
        .toList();

    final snackList = menuProvider.menus
        .where((m) =>
    m.kategori?.toLowerCase() == 'snack' ||
        m.kategori?.toLowerCase() == 'cemilan')
        .toList();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop && pesananProvider.cart.isNotEmpty) {
          print('⚠️ Leaving with items in cart');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Buat Pesanan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (pesananProvider.cart.isNotEmpty) {
                _showClearCartDialog(context);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6D4C41),
            indicatorWeight: 3,
            labelColor: const Color(0xFF6D4C41),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.restaurant), text: 'Makanan', height: 64),
              Tab(icon: Icon(Icons.local_cafe), text: 'Minuman', height: 64),
              Tab(icon: Icon(Icons.cookie), text: 'Snack', height: 64),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: menuProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildMenuList(makananList, pesananProvider, 'makanan'),
                  _buildMenuList(minumanList, pesananProvider, 'minuman'),
                  _buildMenuList(snackList, pesananProvider, 'snack'),
                ],
              ),
            ),
            _buildCartSummary(pesananProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(List menus, PesananProvider pesananProvider, String category) {
    if (menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category == 'makanan'
                  ? Icons.restaurant_menu
                  : category == 'minuman'
                  ? Icons.local_cafe
                  : Icons.cookie,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada ${category.toUpperCase()}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        final isOutOfStock = menu.stok <= 0;
        final isLowStock = menu.stok < 10 && menu.stok > 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: isOutOfStock ? null : () => _showAddToCartDialog(menu),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.grey[300]
                        : const Color(0xFF6D4C41).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          category == 'makanan'
                              ? Icons.restaurant
                              : category == 'minuman'
                              ? Icons.local_cafe
                              : Icons.cookie,
                          size: 48,
                          color: isOutOfStock
                              ? Colors.grey
                              : const Color(0xFF6D4C41).withOpacity(0.5),
                        ),
                      ),
                      if (isOutOfStock)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'HABIS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else if (isLowStock)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Sisa ${menu.stok}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.nama,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock ? Colors.grey : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          currencyFormat.format(menu.harga),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? Colors.grey
                                : const Color(0xFF6D4C41),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isOutOfStock ? null : () => _showAddToCartDialog(menu),
                            icon: Icon(
                              isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                              size: 16,
                            ),
                            label: Text(
                              isOutOfStock ? 'Habis' : 'Tambah',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOutOfStock
                                  ? Colors.grey
                                  : const Color(0xFF6D4C41),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToCartDialog(menu) {
    int qty = 1;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(menu.nama),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: menu.stok < 10
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory,
                      size: 16,
                      color: menu.stok < 10 ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: ${menu.stok}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: menu.stok < 10 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (qty > 1) {
                        setDialogState(() => qty--);
                      }
                    },
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$qty',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (qty < menu.stok) {
                        setDialogState(() => qty++);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stock hanya tersedia ${menu.stok}!'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_circle),
                    color: qty < menu.stok ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: Tanpa es, pedas, dll',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Subtotal: ${currencyFormat.format(menu.harga * qty)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D4C41),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.read<PesananProvider>().addToCart(
                  menu,
                  qty,
                  notes: notesController.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('${menu.nama} x$qty ditambahkan'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tambah'),
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

  Widget _buildCartSummary(PesananProvider pesananProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pesananProvider.cart.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Keranjang (${pesananProvider.cart.length} item)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showCartDetail(context, pesananProvider),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('Detail'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6D4C41),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pembayaran:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                currencyFormat.format(pesananProvider.totalCart),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D4C41),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: pesananProvider.cart.isEmpty
                      ? null
                      : () => _showPaymentDialog(context, 'cash'),
                  icon: const Icon(Icons.money, size: 20),
                  label: const Text('Cash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: pesananProvider.cart.isEmpty
                      ? null
                      : () => _showPaymentDialog(context, 'qris'),
                  icon: const Icon(Icons.qr_code, size: 20),
                  label: const Text('QRIS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCartDetail(BuildContext context, PesananProvider pesananProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Keranjang',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: pesananProvider.cart.length,
                itemBuilder: (context, index) {
                  final item = pesananProvider.cart[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nama'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (item['notes'] != null && item['notes'].isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.note, size: 12, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            item['notes'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  '${currencyFormat.format(item['harga'])} x ${item['qty']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormat.format(item['harga'] * item['qty']),
                                  style: const TextStyle(
                                    color: Color(0xFF6D4C41),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              pesananProvider.removeFromCart(index);
                              if (pesananProvider.cart.isEmpty) {
                                Navigator.pop(ctx);
                              }
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, String metode) {
    final stockError = context.read<PesananProvider>().validateStock();
    if (stockError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stockError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              metode == 'cash' ? Icons.money : Icons.qr_code,
              color: metode == 'cash' ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 12),
            const Text('Pilih Tipe Pesanan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${currencyFormat.format(context.read<PesananProvider>().totalCart)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6D4C41),
              ),
            ),
            const SizedBox(height: 20),
            _buildModeButton(
              context,
              icon: Icons.credit_card,
              label: 'Pesanan Baru\n(Dengan Kartu)',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(dialogContext);
                _createPesananWithCard(context, metode);
              },
            ),
            const SizedBox(height: 12),
            _buildModeButton(
              context,
              icon: Icons.table_restaurant,
              label: 'Tambah Pesanan\n(Pilih Meja)',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(dialogContext);
                _createPesananWithMeja(context, metode);
              },
            ),
            const SizedBox(height: 12),
            _buildModeButton(
              context,
              icon: Icons.shopping_bag,
              label: 'Take Away\n(Bawa Pulang)',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(dialogContext);
                _createPesananTakeAway(context, metode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createPesananWithCard(BuildContext context, String metode) async {
    print('\n🔵 === MODE 1: Pesanan Baru dengan Kartu ===');
    _showLoadingDialog(context, 'Membuat pesanan...');

    try {
      final pesanan = await context.read<PesananProvider>().createPesanan(metode);

      if (!context.mounted) return;
      Navigator.pop(context);

      if (pesanan != null) {
        print('✅ Pesanan created: ${pesanan.nomorPesanan}');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LinkKartuScreen(pesanan: pesanan)),
        );
      } else {
        _showErrorSnackbar(context, 'Gagal membuat pesanan');
      }
    } catch (e) {
      print('❌ ERROR: $e');
      if (context.mounted) {
        Navigator.pop(context);
        _showErrorSnackbar(context, 'Error: $e');
      }
    }
  }

  // ✅ GANTI METHOD _createPesananWithMeja() di create_pesanan_screen.dart
// dengan method baru ini:

  Future<void> _createPesananWithMeja(BuildContext context, String metode) async {
    print('\n🟠 === MODE 2: Tambah Pesanan ===');

    final mejaController = TextEditingController();

    // ✅ STEP 1: Show dialog INPUT NOMOR MEJA (mirip Take Away)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_restaurant, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('Tambah Pesanan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan nomor meja customer:'),
            const SizedBox(height: 12),
            TextField(
              controller: mejaController,
              decoration: InputDecoration(
                labelText: 'Nomor Meja',
                hintText: 'Contoh: 5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.table_restaurant),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan customer sudah ada di meja tersebut',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (mejaController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nomor meja harus diisi!'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirm != true || mejaController.text.trim().isEmpty) return;

    // ✅ STEP 2: Parse nomor meja
    final nomorMeja = int.tryParse(mejaController.text.trim());

    if (nomorMeja == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor meja harus berupa angka!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    print('Nomor meja: $nomorMeja');

    // ✅ STEP 3: Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
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
                  Text('Membuat pesanan tambahan...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // ✅ STEP 4: Create pesanan biasa dulu (status pending)
      final pesanan = await context.read<PesananProvider>().createPesanan(metode);

      if (!context.mounted) return;

      if (pesanan == null) {
        Navigator.pop(context); // Close loading
        _showErrorSnackbar(context, 'Gagal membuat pesanan');
        return;
      }

      // ✅ STEP 5: Assign meja dengan tipe 'tambah_pesanan'
      await context.read<PesananProvider>().assignMeja(pesanan.id!, nomorMeja);

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      print('✅ Tambah pesanan created: ${pesanan.nomorPesanan}');

      // ✅ STEP 6: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Pesanan ${pesanan.nomorPesanan} ditambahkan ke Meja $nomorMeja!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // ✅ Wait untuk user lihat snackbar
      await Future.delayed(const Duration(milliseconds: 800));

      if (!context.mounted) return;

      // ✅ Pop back to HomeScreen
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      print('❌ ERROR: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showErrorSnackbar(context, 'Error: $e');
      }
    }
  }

  // ✅ FIX: Method _createPesananTakeAway di create_pesanan_screen.dart

  Future<void> _createPesananTakeAway(BuildContext context, String metode) async {
    print('\n🟣 === MODE 3: Take Away ===');
    final nameController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Take Away'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan nama customer:'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nama Customer',
                hintText: 'Contoh: Budi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.person),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama customer harus diisi!'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirm == true && nameController.text.trim().isNotEmpty) {
      if (!context.mounted) return;

      print('Customer name: ${nameController.text.trim()}');

      // ✅ Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
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
                    Text('Membuat pesanan take away...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      try {
        final pesanan = await context
            .read<PesananProvider>()
            .createPesananTakeAway(metode, nameController.text.trim());

        if (!context.mounted) return;

        // Close loading dialog
        Navigator.pop(context);

        if (pesanan != null) {
          print('✅ Take away pesanan created: ${pesanan.nomorPesanan}');

          // ✅ Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pesanan take away ${pesanan.nomorPesanan} berhasil dibuat!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // ✅ Wait untuk user lihat snackbar
          await Future.delayed(const Duration(milliseconds: 800));

          if (!context.mounted) return;

          // ✅ CRITICAL FIX: Pop back to HomeScreen (not Navigator.of(context).pop())
          // Ini akan kembali ke HomeScreen yang akan otomatis menampilkan AntrianScreen
          Navigator.of(context).popUntil((route) => route.isFirst);

        } else {
          _showErrorSnackbar(context, 'Gagal membuat pesanan take away');
        }
      } catch (e) {
        print('❌ ERROR: $e');
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          _showErrorSnackbar(context, 'Error: $e');
        }
      }
    }
  }

// Helper method tetap sama

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kosongkan Keranjang?'),
        content: const Text(
          'Anda memiliki item di keranjang. Keluar akan mengosongkan keranjang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PesananProvider>().clearCart();
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kosongkan & Keluar'),
          ),
        ],
      ),
    );
  }
}