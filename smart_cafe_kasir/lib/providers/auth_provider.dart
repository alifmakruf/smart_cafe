import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  late ApiService _api;
  User? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  // Role checkers
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isKasir => _currentUser?.isKasir ?? false;
  bool get isKitchen => _currentUser?.isKitchen ?? false;

  void initialize(ApiService api) {
    _api = api;
    print('AuthProvider initialized');
  }

  /// Load saved session on app start
  Future<bool> loadSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson != null) {
        final userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
        _isAuthenticated = true;

        print('Session loaded: ${_currentUser!.nama} (${_currentUser!.posisi})');

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;

    } catch (e) {
      print('Error loading session: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login
  Future<void> login(String nama, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      print('\n========================================');
      print('=== LOGIN ATTEMPT ===');
      print('Nama: $nama');
      print('========================================');

      final response = await _api.login(nama, password);

      print('\n=== LOGIN RESPONSE ===');
      print('Response: $response');
      print('========================================\n');

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        _currentUser = User.fromJson(userData);
        _isAuthenticated = true;

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', json.encode(userData));

        print('✓ Login successful: ${_currentUser!.nama}');
        print('  Posisi: ${_currentUser!.posisi}');
        print('  Session saved to SharedPreferences');

        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception(response['message'] ?? 'Login gagal');
      }

    } catch (e) {
      print('❌ Login error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      print('\n========================================');
      print('=== LOGOUT ===');
      print('User: ${_currentUser?.nama}');
      print('========================================');

      // Call API logout
      await _api.logout();

      // Clear session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');

      _currentUser = null;
      _isAuthenticated = false;

      print('✓ Logout successful');
      print('Session cleared');
      print('========================================\n');

      notifyListeners();

    } catch (e) {
      print('❌ Logout error: $e');

      // Clear local session even if API fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');

      _currentUser = null;
      _isAuthenticated = false;

      notifyListeners();
      rethrow;
    }
  }

  /// Check if user has permission for specific role
  bool hasRole(String role) {
    return _currentUser?.posisi == role;
  }

  /// Get display name
  String get displayName => _currentUser?.nama ?? 'Guest';

  /// Get posisi display
  String get posisiDisplay => _currentUser?.posisiDisplay ?? '';
}