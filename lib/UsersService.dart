import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/AppUser.dart';

class AdminUserService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<List<AppUser>> listUsers(String jwtToken) async {
    try {
      final url = Uri.parse('$_baseUrl/admin/users');
      // print('📤 Sending GET request to: $url');
      // print('🔐 JWT Token: $jwtToken');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5)); // ⏱️ Set timeout here

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final users = data.map((json) => AppUser.fromJson(json)).toList();
        return users;
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Unknown error';
        // print('❌ Error: $error');
        throw Exception(error);
      }
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    }
    catch (e) {
      // print('🔥 Exception occurred while fetching users: $e');
      throw Exception('Error fetching users: $e');
    }
  }

  static Future<UserListResult> listUsersNew(String jwtToken) async {
    try {
      final url = Uri.parse('$_baseUrl/admin/users');
      final response = await http
          .get(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 5)); // ⏱️ Set timeout here

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final users = data.map((json) => AppUser.fromJson(json)).toList();
        return UserListResult(users: users);
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Unknown error';
        return UserListResult(users: [], error: error);
      }
    } on TimeoutException {
      return UserListResult(
        users: [],
        error:
        'Request timed out. Please check your connection or try again later.',
      );
    } catch (e) {
      return UserListResult(users: [], error: 'Error fetching users: $e');
    }
  }

  /// Create a user with email and password via Node.js backend
  static Future<void> createUser(String email, String password, String name, String jwtToken) async {
    final url = Uri.parse('$_baseUrl/admin/create-user');

    print('📤 Sending POST request to: $url');
    print('📧 Name: $name');
    print('📧 Email: $email');
    print('🔐 JWT Token: $jwtToken');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Failed to create user';
        throw Exception(error);
      }

      print('✅ User created successfully.');
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('🔥 Exception while creating user: $e');
      rethrow;
    }
  }

  static Future<void> resetPassword(String userId, String newPassword, String jwt) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/reset-password/$userId'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to reset password');
    }
  }


  static Future<void> editUser(String userId, String jwtToken, {String? name, String? email, List<String>? labels }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/edit-user/$userId'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (labels != null) 'labels' : labels,
      }),
    );

    if (response.statusCode != 200) {
      print('❌ Delete failed: ${response.body}');
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update user');
    }
  }

  static Future<bool> updateUserStatus({
    required String userId,
    required String jwtToken,
    required bool status,
  }) async {
    final url = Uri.parse('$_baseUrl/admin/update-user-status'); // Update with your server URL

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'status': status,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      } else {
        print('❌ Server error: ${res.statusCode} ${res.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return false;
    }
  }

  /// Delete user by userId with admin JWT
  static Future<void> deleteUser(String userId, String jwtToken) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/delete-user/$userId'), // 👈 ensure this matches backend route
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Delete failed: ${response.body}');
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete user');
    }
  }

}

class UserListResult {
  final List<AppUser> users;
  final String? error;

  UserListResult({required this.users, this.error});
}
