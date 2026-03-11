import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../services/api_service.dart';

class MenuProvider with ChangeNotifier {
  late ApiService _api;
  List<Menu> _menus = [];
  bool _isLoading = false;

  List<Menu> get menus => _menus;
  bool get isLoading => _isLoading;

  // Initialize API
  void initialize(ApiService api) {
    _api = api;
  }

  // ============================================================
  // FETCH DENGAN LOADING (untuk pertama kali / manual refresh)
  // ============================================================
  Future<void> fetchMenus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _api.getMenus();
      _menus = data.map((json) => Menu.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching menus: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // FETCH SILENT (AUTO REFRESH) — TANPA LOADING INDICATOR
  // ============================================================
  Future<void> fetchMenusSilent() async {
    try {
      final data = await _api.getMenus();
      _menus = data.map((json) => Menu.fromJson(json)).toList();
      notifyListeners(); // update UI quietly
    } catch (e) {
      print('Error fetching menus (silent): $e');
    }
  }

  // ============================================================
  // CRUD METHODS
  // ============================================================
  Future<void> addMenu(Menu menu) async {
    try {
      await _api.createMenu(menu.toJson());
      await fetchMenus();
    } catch (e) {
      print('Error adding menu: $e');
      rethrow;
    }
  }

  Future<void> updateMenu(int id, Menu menu) async {
    try {
      await _api.updateMenu(id, menu.toJson());
      await fetchMenus();
    } catch (e) {
      print('Error updating menu: $e');
      rethrow;
    }
  }

  Future<void> deleteMenu(int id) async {
    try {
      await _api.deleteMenu(id);
      await fetchMenus();
    } catch (e) {
      print('Error deleting menu: $e');
      rethrow;
    }
  }
}