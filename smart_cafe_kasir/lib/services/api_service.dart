import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String baseUrl;

  ApiService({this.baseUrl = 'http://10.241.29.112:8000/api/v1'});

  void updateBaseUrl(String url) {
    baseUrl = url;
    print('API Base URL updated: $baseUrl');
  }

  Future<bool> testConnection() async {
    try {
      print('\n🔍 ========== CONNECTION TEST ==========');
      print('Testing URL: $baseUrl/menus');
      print('Timeout: 5 seconds');

      final startTime = DateTime.now();

      final response = await http.get(
        Uri.parse('$baseUrl/menus'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('❌ Connection timeout after 5 seconds');
          throw Exception('Connection timeout');
        },
      );

      final duration = DateTime.now().difference(startTime);

      print('Response received in: ${duration.inMilliseconds}ms');
      print('Status code: ${response.statusCode}');
      print('Response body length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        print('✅ Connection successful!');
        print('========================================\n');
        return true;
      } else {
        print('⚠️ Unexpected status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('========================================\n');
        return false;
      }
    } catch (e) {
      print('❌ Connection test failed!');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('========================================\n');
      return false;
    }
  }

  Future<List<dynamic>> getList(String endpoint) async {
    print('GET request: $baseUrl/$endpoint');
    final response = await http.get(Uri.parse('$baseUrl/$endpoint'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load data');
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final fullUrl = '$baseUrl/$endpoint';

      print('\n========================================');
      print('=== API POST Request ===');
      print('Full URL: $fullUrl');
      print('Endpoint: $endpoint');
      print('Base URL: $baseUrl');
      print('Data: $data');
      print('========================================');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      print('\n=== API Response ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('========================================\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            return responseData['data'];
          }
          return responseData;
        }

        return responseData;
      }

      print('\n❌ API ERROR');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      throw Exception('Failed to post data: ${response.statusCode}');

    } catch (e) {
      print('\n❌ EXCEPTION in POST $endpoint');
      print('Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    print('\n=== API PUT Request ===');
    print('URL: $baseUrl/$endpoint');
    print('Data: $data');

    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    print('Response: ${response.statusCode}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update data');
  }

  Future<void> delete(String endpoint) async {
    final response = await http.delete(Uri.parse('$baseUrl/$endpoint'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete data');
    }
  }

  // ========================================
  // AUTH APIs
  // ========================================

  Future<Map<String, dynamic>> login(String nama, String password) async {
    print('\n========================================');
    print('=== LOGIN REQUEST ===');
    print('Nama: $nama');

    // Auth endpoint berbeda (tanpa /v1)
    final authUrl = baseUrl.replaceAll('/v1', '');
    final fullUrl = '$authUrl/auth/login';

    print('URL: $fullUrl');
    print('========================================');

    final response = await http.post(
      Uri.parse(fullUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'nama': nama,
        'password': password,
      }),
    );

    print('\n=== LOGIN RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    print('========================================\n');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401 || response.statusCode == 404) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Login gagal');
    } else {
      throw Exception('Login gagal: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> logout() async {
    final authUrl = baseUrl.replaceAll('/v1', '');
    final response = await http.post(
      Uri.parse('$authUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Logout gagal');
  }

  Future<Map<String, dynamic>> register(String nama, String posisi, String password) async {
    final authUrl = baseUrl.replaceAll('/v1', '');
    final response = await http.post(
      Uri.parse('$authUrl/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'nama': nama,
        'posisi': posisi,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Register gagal');
    }
  }

  // ========================================
  // USER MANAGEMENT APIs (Admin Only)
  // ========================================

  Future<List<dynamic>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));

    print('Users response status: ${response.statusCode}');
    print('Users response body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'] as List<dynamic>;
      }

      return decoded as List<dynamic>;
    }

    throw Exception('Failed to load users: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) =>
      put('users/$id', data);

  Future<Map<String, dynamic>> changePassword(int id, String newPassword) =>
      put('users/$id/password', {'new_password': newPassword});

  Future<void> deleteUser(int id) => delete('users/$id');

  // ========================================
  // EXISTING APIs
  // ========================================

  // Menu APIs
  Future<List<dynamic>> getMenus() => getList('menus');
  Future<Map<String, dynamic>> createMenu(Map<String, dynamic> data) => post('menus', data);
  Future<Map<String, dynamic>> updateMenu(int id, Map<String, dynamic> data) => put('menus/$id', data);
  Future<void> deleteMenu(int id) => delete('menus/$id');

  // Meja APIs
  Future<List<dynamic>> getMejas() => getList('mejas');
  Future<Map<String, dynamic>> createMeja(Map<String, dynamic> data) => post('mejas', data);
  Future<Map<String, dynamic>> updateMeja(int id, Map<String, dynamic> data) => put('mejas/$id', data);
  Future<void> deleteMeja(int id) => delete('mejas/$id');

  // Kartu APIs
  Future<List<dynamic>> getKartus() => getList('kartus');
  Future<Map<String, dynamic>> createKartu(Map<String, dynamic> data) => post('kartus', data);
  Future<void> deleteKartu(int id) => delete('kartus/$id');

  // Pesanan APIs
  Future<List<dynamic>> getPesanans() => getList('pesanans');
  Future<Map<String, dynamic>> createPesanan(Map<String, dynamic> data) => post('pesanans', data);
  Future<Map<String, dynamic>> linkKartu(int pesananId, String kartuUid) {
    print('\n🔍 linkKartu called');
    print('  pesananId: $pesananId');
    print('  kartuUid: $kartuUid');
    print('  endpoint will be: pesanans/$pesananId/link-kartu');

    return post('pesanans/$pesananId/link-kartu', {'kartu_uid': kartuUid});
  }

  // ✅ FIX: assignMeja method di api_service.dart

  // api_service.dart

  Future<Map<String, dynamic>> assignMeja(int pesananId, int mejaId) async {
    try {
      print('\n========================================');
      print('=== API: Assign Meja ===');
      print('URL: $baseUrl/pesanans/$pesananId/assign-meja');
      print('Method: POST');
      print('========================================');

      // ✅ GUNAKAN POST
      final response = await http.post(
        Uri.parse('$baseUrl/pesanans/$pesananId/assign-meja'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'meja_id': mejaId}),
      );

      print('\n=== API RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('========================================\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            return responseData['data'];
          }
          return responseData;
        }

        return responseData;
      }

      throw Exception('Failed to assign meja: ${response.statusCode}');

    } catch (e) {
      print('\n❌ EXCEPTION in assignMeja');
      print('Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePesananStatus(int id, String status) {
    return put('pesanans/$id/status', {'status': status});
  }

  Future<List<dynamic>> getHistory() async {
    print('GET request: $baseUrl/pesanans/history');
    final response = await http.get(Uri.parse('$baseUrl/pesanans/history'));

    print('History response status: ${response.statusCode}');
    print('History response body: ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load history: ${response.statusCode}');
  }
}