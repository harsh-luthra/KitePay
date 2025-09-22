import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/AppUser.dart';

class AdminUserService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<PaginatedAppUsers> listUsers({String? cursor,
    int limit = 50, required String jwtToken}) async {
    try {
      String url = '$_baseUrl/admin/users';
      Map<String, String> queryParams = {
        'limit': limit.toString(),
      };
      // print('📤 Sending GET request to: $url');
      // print('🔐 JWT Token: $jwtToken');

      if (cursor != null) queryParams['cursor'] = cursor;

      url += '?${Uri(queryParameters: queryParams).query}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5)); // ⏱️ Set timeout here

      if (response.statusCode == 200) {
        // final List<dynamic> data = jsonDecode(response.body);
        final responseData = json.decode(response.body);
        final List data = responseData['transactions'];
        final String? nextCursor = responseData['nextCursor'];
        // print(response.body);

        return PaginatedAppUsers(
          appUsers : data.map((e) => AppUser.fromJson(e)).toList(),
          nextCursor: nextCursor,
        );

        // final users = data.map((json) => AppUser.fromJson(json)).toList();
        // return users;

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

  static Future<List<AppUser>> listSubAdmins(String jwtToken, {String? search}) async {
    try {
      final baseUrl = '$_baseUrl/admin/subadmins';
      final url = (search != null && search.isNotEmpty)
          ? Uri.parse('$baseUrl?search=${Uri.encodeQueryComponent(search)}')
          : Uri.parse(baseUrl);
      //
      // print('🔐 JWT Token: $jwtToken');
      // print('🔍 Searching for: $search');
      // print('📤 Sending GET request to: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // print(response.body);
        return data.map((json) => AppUser.fromJson(json)).toList();
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Unknown error';
        throw Exception(error);
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  // static Future<UserListResult> listUsersNew(String jwtToken) async {
  //   try {
  //     final url = Uri.parse('$_baseUrl/admin/users');
  //     final response = await http
  //         .get(
  //       url,
  //       headers: {
  //         'Authorization': 'Bearer $jwtToken',
  //         'Content-Type': 'application/json',
  //       },
  //     )
  //         .timeout(const Duration(seconds: 5)); // ⏱️ Set timeout here
  //
  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = jsonDecode(response.body);
  //       final users = data.map((json) => AppUser.fromJson(json)).toList();
  //       return UserListResult(users: users);
  //     } else {
  //       final body = jsonDecode(response.body);
  //       final error = body['error'] ?? 'Unknown error';
  //       return UserListResult(users: [], error: error);
  //     }
  //   } on TimeoutException {
  //     return UserListResult(
  //       users: [],
  //       error:
  //       'Request timed out. Please check your connection or try again later.',
  //     );
  //   } catch (e) {
  //     return UserListResult(users: [], error: 'Error fetching users: $e');
  //   }
  // }

  /// Create a user with email and password via Node.js backend
  static Future<bool> createUser(
      String email,
      String password,
      String name,
      String role,
      String jwtToken,
      ) async {
    final url = Uri.parse('$_baseUrl/admin/create-user');

    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      // Success path
      if (resp.statusCode == 201) return true;

      // Optional: log server error message if present
      try {
        final body = jsonDecode(resp.body);
        debugPrint('Create user failed: ${body['error'] ?? body}');
      } catch (_) {
        debugPrint('Create user failed: ${resp.statusCode} ${resp.body}');
      }
      return false;
    } on TimeoutException {
      debugPrint('Create user timed out');
      return false;
    } catch (e) {
      debugPrint('Create user exception: $e');
      return false;
    }
  }

  static Future<bool> assignUserToSubAdmin({
    required String subAdminId,
    required String userId,
    required String jwtToken,
    bool unAssign = false, // when true, clears parentId on server
  }) async {
    final url = Uri.parse('$_baseUrl/admin/assign-user/$subAdminId');

    try {
      final resp = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'userId': userId,
          'unassign': unAssign, // optional; omit or false to assign
        }),
      );

      // Success: backend returns 200 OK on update
      if (resp.statusCode == 200) return true;

      // Log server message if present
      try {
        final body = jsonDecode(resp.body);
        debugPrint('Assign user failed: ${body['message'] ?? body['error'] ?? body}');
      } catch (_) {
        debugPrint('Assign user failed: ${resp.statusCode} ${resp.body}');
      }
      return false;
    } on TimeoutException {
      debugPrint('Assign user timed out');
      return false;
    } catch (e) {
      debugPrint('Assign user exception: $e');
      return false;
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

  static Future<bool> getMyMetaData({
    required String jwtToken,
  }) async {
    final url = Uri.parse('$_baseUrl/admin/getMyMetaData'); // Update with your server URL

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
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

}

class PaginatedAppUsers {
  final List<AppUser> appUsers;
  final String? nextCursor;
  PaginatedAppUsers({required this.appUsers, required this.nextCursor});
}

//
// class UserListResult {
//   final List<AppUser> users;
//   final String? error;
//   UserListResult({required this.users, this.error});
// }
