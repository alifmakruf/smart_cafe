import 'package:flutter/material.dart';
import '../models/kartu.dart';
import '../services/api_service.dart';

class KartuProvider with ChangeNotifier {
  ApiService? _api;
  List<Kartu> _kartus = [];
  bool _isLoading = false;

  List<Kartu> get kartus => _kartus;
  bool get isLoading => _isLoading;

  /// Wajib dipanggil sebelum menggunakan provider
  void initialize(ApiService api) {
    _api = api;
  }

  bool get _ready => _api != null;

  // ============================================================
  // FETCH DENGAN LOADING (untuk pertama kali load)
  // ============================================================
  Future<void> fetchKartus() async {
    if (!_ready) {
      print('KartuProvider ERROR: ApiService belum di-initialize!');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api!.getKartus();
      _kartus = data.map((json) => Kartu.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching kartus: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // SILENT FETCH (AUTO REFRESH) — TANPA LOADING INDICATOR
  // ============================================================
  Future<void> fetchKartusSilent() async {
    if (!_ready) {
      print('KartuProvider ERROR: ApiService belum di-initialize!');
      return;
    }

    try {
      final data = await _api!.getKartus();
      _kartus = data.map((json) => Kartu.fromJson(json)).toList();
      notifyListeners(); // update UI quietly
    } catch (e) {
      print('Error fetching kartus (silent): $e');
    }
  }

  // ============================================================
  // CRUD METHODS
  // ============================================================
  Future<void> addKartu(Kartu kartu) async {
    if (!_ready) {
      throw Exception("ApiService belum di-initialize!");
    }

    try {
      await _api!.createKartu(kartu.toJson());
      await fetchKartus();
    } catch (e) {
      print('Error adding kartu: $e');
      rethrow;
    }
  }

  Future<void> deleteKartu(int id) async {
    if (!_ready) {
      throw Exception("ApiService belum di-initialize!");
    }

    try {
      await _api!.deleteKartu(id);
      await fetchKartus();
    } catch (e) {
      print('Error deleting kartu: $e');
      rethrow;
    }
  }
}