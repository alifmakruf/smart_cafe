import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  ApiService? _api;
  List<User> _users = [];
  bool _isLoading = false;

  List<User> get users => _users;
  bool get isLoading => _isLoading;

  void initialize(ApiService api) {
    _api = api;
  }

  Future<void> fetchUsers() async {
    if (_api == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      print('📡 Fetching users from: ${_api!.baseUrl}/users');
      final data = await _api!.getUsers();
      _users = data.map((json) => User.fromJson(json)).toList();
      print('✅ Fetched ${_users.length} users');
    } catch (e) {
      print('❌ Error fetching users: $e');
      _users = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}