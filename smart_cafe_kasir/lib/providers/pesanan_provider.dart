import 'package:flutter/material.dart';
import '../models/pesanan.dart';
import '../models/menu.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';

class PesananProvider with ChangeNotifier {
  late ApiService _api;
  final MqttService _mqtt = MqttService();
  List<Pesanan> _pesanans = [];
  List<Pesanan> _history = [];
  List<Map<String, dynamic>> _cart = [];
  bool _isLoading = false;

  List<Pesanan> get pesanans => _pesanans;
  List<Pesanan> get history => _history;
  List<Map<String, dynamic>> get cart => _cart;
  bool get isLoading => _isLoading;

  double get totalCart {
    return _cart.fold(0, (sum, item) => sum + (item['harga'] * item['qty']));
  }

  void initialize(ApiService api) {
    _api = api;
    print('PesananProvider initialized with API service');
  }

  // ==========================================
  // CART MANAGEMENT
  // ==========================================

  void addToCart(Menu menu, int qty, {String? notes}) {
    final existingIndex = _cart.indexWhere((item) =>
    item['menu_id'] == menu.id && item['notes'] == notes);

    if (existingIndex >= 0) {
      _cart[existingIndex]['qty'] += qty;
      print('Updated cart item: ${menu.nama}, new qty: ${_cart[existingIndex]['qty']}');
    } else {
      _cart.add({
        'menu_id': menu.id,
        'nama': menu.nama,
        'harga': menu.harga,
        'qty': qty,
        'notes': notes ?? '',
        'stok': menu.stok, // ✅ Simpan stok untuk validasi
      });
      print('Added to cart: ${menu.nama} x$qty (notes: $notes)');
    }
    notifyListeners();
  }

  void updateCartItemQty(int index, int newQty) {
    if (index >= 0 && index < _cart.length) {
      if (newQty > 0) {
        _cart[index]['qty'] = newQty;
        print('Updated cart item qty: ${_cart[index]['nama']} = $newQty');
      } else {
        removeFromCart(index);
      }
      notifyListeners();
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cart.length) {
      final removedItem = _cart[index];
      _cart.removeAt(index);
      print('Removed from cart: ${removedItem['nama']}');
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    print('Cart cleared');
    notifyListeners();
  }

  // ✅ VALIDASI STOCK SEBELUM CHECKOUT
  String? validateStock() {
    for (var item in _cart) {
      int stok = item['stok'] ?? 0;
      int qty = item['qty'];

      if (qty > stok) {
        return 'Stock ${item['nama']} tidak cukup! (Tersedia: $stok, Diminta: $qty)';
      }
    }
    return null; // All OK
  }

  // ==========================================
  // CREATE PESANAN (dengan Link Kartu)
  // ==========================================

  Future<Pesanan?> createPesanan(String metodePembayaran) async {
    try {
      final stockError = validateStock();
      if (stockError != null) {
        throw Exception(stockError);
      }

      final items = _cart.map((item) => {
        'menu_id': item['menu_id'],
        'qty': item['qty'],
        'notes': item['notes'] ?? '',
      }).toList();

      print('\n========================================');
      print('=== Creating Pesanan ===');
      print('Items: $items');
      print('Total: $totalCart');
      print('Metode: $metodePembayaran');
      print('========================================');

      final data = await _api.createPesanan({
        'items': items,
        'total_harga': totalCart,
        'metode_pembayaran': metodePembayaran,
        // ❌ JANGAN kirim tipe di sini (akan diset nanti saat link/assign)
      });

      if (data == null) {
        throw Exception('Response dari server kosong');
      }

      Map<String, dynamic> pesananData;
      if (data is Map<String, dynamic>) {
        pesananData = data.containsKey('data') ? data['data'] : data;
      } else {
        throw Exception('Format response tidak valid');
      }

      if (!pesananData.containsKey('nomor_pesanan')) {
        throw Exception('Response tidak mengandung nomor_pesanan');
      }

      Pesanan pesanan = Pesanan.fromJson(pesananData);

      print('\n✅ Pesanan created successfully');
      print('  ID: ${pesanan.id}');
      print('  Nomor: ${pesanan.nomorPesanan}');
      print('  Status: ${pesanan.status}');
      print('========================================\n');

      // Cart tidak di-clear dulu (biar stock belum berkurang)
      return pesanan;

    } catch (e, stackTrace) {
      print('\n========================================');
      print('❌ ERROR Creating Pesanan');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('========================================\n');
      rethrow;
    }
  }


  // ==========================================
  // CREATE PESANAN TAKE AWAY
  // ==========================================

  Future<Pesanan?> createPesananTakeAway(String metodePembayaran, String customerName) async {
    try {
      // ✅ CEK STOCK DULU
      final stockError = validateStock();
      if (stockError != null) {
        throw Exception(stockError);
      }

      final items = _cart.map((item) => {
        'menu_id': item['menu_id'],
        'qty': item['qty'],
        'notes': item['notes'] ?? '',
      }).toList();

      print('\n========================================');
      print('=== Creating Pesanan Take Away ===');
      print('Customer: $customerName');
      print('Items: $items');
      print('Total: $totalCart');
      print('========================================');

      final data = await _api.createPesanan({
        'items': items,
        'total_harga': totalCart,
        'metode_pembayaran': metodePembayaran,
        'customer_name': customerName, // ✅ Kirim nama customer
        'tipe': 'takeaway', // ✅ Kirim tipe pesanan
      });

      if (data == null) {
        throw Exception('Response dari server kosong');
      }

      Map<String, dynamic> pesananData;

      if (data is Map<String, dynamic>) {
        if (data.containsKey('data')) {
          pesananData = data['data'];
        } else {
          pesananData = data;
        }
      } else {
        throw Exception('Format response tidak valid');
      }

      Pesanan pesanan = Pesanan.fromJson(pesananData);

      print('✓ Take away pesanan created: ${pesanan.nomorPesanan}');

      // ✅ TAKE AWAY: Update status ke PAID via API langsung
      print('Updating status to paid...');
      await _api.updatePesananStatus(pesanan.id!, 'paid');

      print('✓ Status updated to paid');

      // Clear cart & refresh
      clearCart();
      await fetchPesanans();

      print('========================================\n');
      return pesanan;
    } catch (e, stackTrace) {
      print('\n========================================');
      print('✗ ERROR Creating Take Away Pesanan');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('========================================\n');
      rethrow;
    }
  }

  // ==========================================
  // FETCH PESANANS
  // ==========================================

  Future<void> fetchPesanans() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Fetching active pesanans...');
      final data = await _api.getPesanans();

      _pesanans = data
          .map((json) => Pesanan.fromJson(json))
          .where((p) => p.status != 'pending') // ✅ Exclude pending
          .toList();

      print('✓ Fetched ${_pesanans.length} active pesanans');
    } catch (e) {
      print('✗ Error fetching pesanans: $e');
      _pesanans = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPesanansSilent() async {
    try {
      final data = await _api.getPesanans();
      _pesanans = data
          .map((json) => Pesanan.fromJson(json))
          .where((p) => p.status != 'pending')
          .toList();
      notifyListeners();
    } catch (e) {
      print('✗ Error fetching pesanans (silent): $e');
    }
  }

  Future<void> fetchHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Fetching history...');
      final data = await _api.getHistory();
      _history = data.map((json) => Pesanan.fromJson(json)).toList();
      print('✓ Fetched ${_history.length} history records');
    } catch (e) {
      print('✗ Error fetching history: $e');
      _history = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ==========================================
  // LINK KARTU
  // ==========================================

  // ==========================================
// LINK KARTU - FIXED VERSION
// ==========================================

  // Method linkKartu - UPDATE
  Future<void> linkKartu(int pesananId, String kartuUid) async {
    try {
      print('\n========================================');
      print('=== Linking Kartu ===');
      print('Pesanan ID: $pesananId');
      print('Kartu UID: $kartuUid');

      final data = await _api.linkKartu(pesananId, kartuUid);

      if (data != null && (data['success'] == true || data['id'] != null)) {
        print('✅ Kartu linked successfully');

        clearCart();
        await fetchPesanans();

        // ✅ CHECK: Apakah sudah punya meja_id?
        try {
          final pesanan = _pesanans.firstWhere((p) => p.id == pesananId);

          if (pesanan.mejaId != null) {
            // Sudah ada meja, publish MQTT
            print('📤 Publishing card_linked event to MQTT...');
            _mqtt.publishCardLinked(kartuUid, pesananId, pesanan.mejaId!);
          } else {
            // ⚠️ Belum ada meja (ini case yang sekarang terjadi)
            print('⚠️ No meja_id yet, need to assign meja manually');
            // Flutter perlu navigasi ke pilih meja
          }
        } catch (e) {
          print('⚠️ Could not find pesanan in list');
        }

        print('========================================\n');
      } else {
        throw Exception('Failed to link kartu');
      }
    } catch (e, stackTrace) {
      print('\n========================================');
      print('❌ ERROR in linkKartu');
      print('Error: $e');
      print('========================================\n');
      rethrow;
    }
  }


  // ==========================================
  // ASSIGN MEJA
  // ==========================================

  // ==========================================
// ASSIGN MEJA (untuk Tambah Pesanan)
// ==========================================

  Future<void> assignMeja(int pesananId, int mejaId) async {
    try {
      print('\n========================================');
      print('=== Assigning Meja (Tambah Pesanan) ===');
      print('Pesanan ID: $pesananId');
      print('Meja ID: $mejaId');

      // ✅ KIRIM tipe 'tambah_pesanan' ke backend
      await _api.post('pesanans/$pesananId/assign-meja', {
        'meja_id': mejaId,
        'tipe': 'tambah_pesanan', // ✅ KEY FIX!
      });

      print('✅ Meja assigned successfully');

      // ✅ Clear cart (stock sudah berkurang)
      clearCart();

      // ✅ Refresh pesanan list
      await fetchPesanans();

      print('========================================\n');
    } catch (e) {
      print('❌ Error assigning meja: $e');
      rethrow;
    }
  }



  // ==========================================
  // UPDATE STATUS
  // ==========================================

  Future<void> updateStatus(int pesananId, String status) async {
    try {
      print('\n========================================');
      print('=== Updating Status ===');
      print('Pesanan ID: $pesananId');
      print('New Status: $status');

      await _api.updatePesananStatus(pesananId, status);

      // ✅ FIX: Cari pesanan dengan aman (bisa jadi belum di list)
      Pesanan? pesanan;
      try {
        pesanan = _pesanans.firstWhere((p) => p.id == pesananId);
      } catch (e) {
        print('⚠️ Pesanan not found in current list (might be pending)');
      }

      // MQTT notifications (hanya jika pesanan ditemukan & punya meja)
      if (pesanan != null && pesanan.mejaId != null) {
        _mqtt.publishOrderStatus(pesananId, pesanan.mejaId!, status);

        if (status == 'preparing') {
          _mqtt.publishLedControl(pesanan.mejaId!, true, false);
        } else if (status == 'ready') {
          _mqtt.publishLedControl(pesanan.mejaId!, false, true);
        } else if (status == 'completed') {
          _mqtt.publishLedControl(pesanan.mejaId!, false, false);
        }
      }

      await fetchPesanans();

      if (status == 'completed' || status == 'cancelled') {
        await fetchHistory();
      }

      print('✓ Status updated successfully');
      print('========================================\n');
    } catch (e) {
      print('✗ Error updating status: $e');
      rethrow;
    }
  }

  // ==========================================
  // ✅ COMPLETE ORDER (langsung complete + deactivate)
  // ==========================================

  Future<void> completeOrder(int pesananId) async {
    try {
      print('\n========================================');
      print('=== Completing Order ===');
      print('Pesanan ID: $pesananId');

      // ✅ FIX: Cari pesanan dengan aman
      Pesanan? pesanan;
      try {
        pesanan = _pesanans.firstWhere((p) => p.id == pesananId);
      } catch (e) {
        print('⚠️ Pesanan not found in list, fetching...');
        await fetchPesanans();
        pesanan = _pesanans.firstWhere((p) => p.id == pesananId);
      }

      // ✅ Update status ke completed
      await updateStatus(pesananId, 'completed');

      // ✅ Jika ada kartu, deactivate
      if (pesanan.kartuUid != null && pesanan.kartuUid!.isNotEmpty) {
        print('Deactivating card: ${pesanan.kartuUid}');
        await deactivateCard(pesanan.kartuUid!);
      }

      print('✓ Order completed successfully');
      print('========================================\n');

    } catch (e) {
      print('✗ Error completing order: $e');
      rethrow;
    }
  }

  // ==========================================
  // ✅ CANCEL ORDER (restore stock + deactivate kartu)
  // ==========================================

  Future<void> cancelOrder(int pesananId) async {
    try {
      print('\n========================================');
      print('=== Cancelling Order ===');
      print('Pesanan ID: $pesananId');

      // ✅ FIX: Cari pesanan dengan aman
      Pesanan? pesanan;
      try {
        pesanan = _pesanans.firstWhere((p) => p.id == pesananId);
      } catch (e) {
        print('⚠️ Pesanan not found in list, fetching...');
        await fetchPesanans();
        pesanan = _pesanans.firstWhere((p) => p.id == pesananId);
      }

      // ✅ Update status ke cancelled (backend akan restore stock)
      await updateStatus(pesananId, 'cancelled');

      // ✅ Jika ada kartu, deactivate
      if (pesanan.kartuUid != null && pesanan.kartuUid!.isNotEmpty) {
        print('Deactivating card: ${pesanan.kartuUid}');
        try {
          await deactivateCard(pesanan.kartuUid!);
        } catch (e) {
          print('⚠️ Failed to deactivate card (maybe already inactive): $e');
        }
      }

      print('✓ Order cancelled successfully');
      print('========================================\n');

    } catch (e) {
      print('✗ Error cancelling order: $e');
      rethrow;
    }
  }

  // ==========================================
  // DEACTIVATE CARD
  // ==========================================

  Future<void> deactivateCard(String kartuUid) async {
    try {
      print('\n========================================');
      print('=== Deactivating Card ===');
      print('Kartu UID: $kartuUid');

      final data = await _api.post('pesanans/deactivate-card', {
        'kartu_uid': kartuUid,
      });

      if (data != null) {
        bool isSuccess = false;

        if (data.containsKey('success') && data['success'] == true) {
          isSuccess = true;
        } else if (data.containsKey('pesanan_id')) {
          isSuccess = true;
        }

        if (isSuccess) {
          print('✓ Card deactivated & order completed');
          await fetchPesanans();
          await fetchHistory();
        } else {
          throw Exception(data['message'] ?? 'Failed to deactivate card');
        }
      } else {
        throw Exception('No response from server');
      }
    } catch (e, stackTrace) {
      print('\n========================================');
      print('✗ ERROR Deactivating Card');
      print('Error: $e');
      print('========================================\n');
      rethrow;
    }
  }



  // ==========================================
  // HELPERS
  // ==========================================

  Pesanan? getPesananById(int id) {
    try {
      return _pesanans.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Pesanan? getPesananByNomor(String nomorPesanan) {
    try {
      return _pesanans.firstWhere((p) => p.nomorPesanan == nomorPesanan);
    } catch (e) {
      return null;
    }
  }

  int get totalActivePesanans => _pesanans.length;
  int get totalHistoryPesanans => _history.length;
}