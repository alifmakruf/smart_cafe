import 'package:flutter/material.dart';
import '../models/meja.dart';
import '../services/api_service.dart';

class MejaProvider with ChangeNotifier {
  late ApiService _api;
  List<Meja> _mejas = [];
  bool _isLoading = false;

  List<Meja> get mejas => _mejas;
  bool get isLoading => _isLoading;

  // Initialize with API service
  void initialize(ApiService api) {
    _api = api;
  }

  // ============================================================
  // FETCH DENGAN LOADING (untuk pertama kali load)
  // ============================================================
  Future<void> fetchMejas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getMejas();
      _mejas = data.map((json) => Meja.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching mejas: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // SILENT FETCH (AUTO REFRESH) — TANPA LOADING INDICATOR
  // ============================================================
  Future<void> fetchMejasSilent() async {
    try {
      final data = await _api.getMejas();
      _mejas = data.map((json) => Meja.fromJson(json)).toList();
      notifyListeners(); // update UI quietly
    } catch (e) {
      print('Error fetching mejas (silent): $e');
    }
  }

  // ============================================================
  // CRUD METHODS
  // ============================================================
  Future<void> addMeja(Meja meja) async {
    try {
      await _api.createMeja(meja.toJson());
      await fetchMejas();
    } catch (e) {
      print('Error adding meja: $e');
      rethrow;
    }
  }

  Future<void> updateMeja(int id, Meja meja) async {
    try {
      await _api.updateMeja(id, meja.toJson());
      await fetchMejas();
    } catch (e) {
      print('Error updating meja: $e');
      rethrow;
    }
  }

  Future<void> deleteMeja(int id) async {
    try {
      await _api.deleteMeja(id);
      await fetchMejas();
    } catch (e) {
      print('Error deleting meja: $e');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE STATUS MEJA (Kosong / Terisi / Offline)
  // ============================================================
  Future<void> updateStatus(int id, String status) async {
    try {
      await _api.put('mejas/$id/status', {'status': status});
      await fetchMejas();
    } catch (e) {
      print('Error updating status: $e');
      rethrow;
    }
  }
}