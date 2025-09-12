import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/WithdrawalRequest.dart';

class WithdrawalPage {
  final List<WithdrawalRequest> requests;
  final String? nextCursor;
  WithdrawalPage({required this.requests, required this.nextCursor});
}

class WithdrawService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<bool> submitWithdrawRequest(WithdrawalRequest request) async {
    try {
      final Map<String, dynamic> body = {
        'userId': request.userId,
        'qrId': request.qrId,
        'holderName': request.holderName,
        'mode': request.mode,
        'amount': request.amount,
      };

      if (request.mode == 'upi') {
        body['upiId'] = request.upiId;
      } else if (request.mode == 'bank') {
        body['bankName'] = request.bankName;
        body['accountNumber'] = request.accountNumber;
        body['ifscCode'] = request.ifscCode;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/user/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Withdrawal request failed: ${response.body}');
        throw Exception('${response.body}');
        return false;
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      print('❌ Withdrawal request failed: $e');
      throw Exception('❌ Withdrawal request failed: $e');
    }
  }

  // Paginated fetch with optional status filter
  static Future<WithdrawalPage> fetchWithdrawalsPaginated({
    required String jwtToken,
    String? status,           // 'pending' | 'approved' | 'rejected' or null for all
    String? cursor,           // server-provided cursor token from previous page
    int limit = 15,           // page size
    String? userId,           // optional: scope to a single user if needed
  }) async {
    try {
      final qp = <String, String>{
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
        if (userId != null) 'userId': userId,
      };

      final uri = Uri.parse('$_baseUrl/user/withdrawals_paginated').replace(queryParameters: qp);
      final response = await http.get(
        uri,
        headers: { 'Authorization': 'Bearer $jwtToken' },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> rawList = (data['withdrawals'] as List?) ?? const [];
        final String? next = data['nextCursor'] as String?;
        final items = rawList.map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>)).toList();
        return WithdrawalPage(requests: items, nextCursor: next);
      } else {
        final body = jsonDecode(response.body);
        final error = body is Map<String, dynamic> ? (body['error'] ?? 'Unknown error') : 'Unknown error';
        throw Exception('Failed to fetch withdrawals: $error');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Exception in fetchWithdrawalsPaginated: $e');
      throw Exception('Failed to fetch withdrawals: $e');
    }
  }

  // Paginated user withdrawals
  static Future<WithdrawalPage> fetchUserWithdrawalsPaginated({
    required String jwtToken,
    required String userId,
    String? status,     // 'pending' | 'approved' | 'rejected' or null
    String? cursor,     // server-provided token from previous page
    int limit = 15,     // page size
  }) async {
    try {
      final qp = <String, String>{
        'userId': userId,
        'limit': '$limit',
        if (status != null) 'status': status,
        if (cursor != null) 'cursor': cursor,
      };

      final uri = Uri.parse('$_baseUrl/user/user_withdrawals').replace(queryParameters: qp);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> rawList = (data['withdrawals'] as List?) ?? const [];
        final String? next = data['nextCursor'] as String?;

        final items = rawList
            .map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
            .toList();

        return WithdrawalPage(requests: items, nextCursor: next);
      } else {
        final body = jsonDecode(response.body);
        final error = body is Map<String, dynamic> ? (body['error'] ?? 'Unknown error') : 'Unknown error';
        throw Exception('Failed to fetch withdrawals: $error');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Exception in fetchUserWithdrawalsPaginated: $e');
      throw Exception('Failed to fetch withdrawals: $e');
    }
  }

  static Future<List<WithdrawalRequest>> fetchAllWithdrawals(String jwtToken, {String? status}) async {
    try {
      final url = status != null
          ? Uri.parse('$_baseUrl/user/withdrawals?status=$status')
          : Uri.parse('$_baseUrl/user/withdrawals');

      // final response = await http.get(url).timeout(const Duration(seconds: 10));

        final response = await http.get(
          Uri.parse('$_baseUrl/user/withdrawals'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
          },
        ).timeout(Duration(seconds: 10));

      // try {
      //   final response = await http.get(
      //     Uri.parse('$_baseUrl/qr-codes'),
      //     headers: {
      //       'Authorization': 'Bearer $jwtToken',
      //     },
      //   ).timeout(Duration(seconds: 10));

      // print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> rawList = data['withdrawals'];
        return rawList.map((e) => WithdrawalRequest.fromJson(e)).toList();
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Unknown error';
        throw Exception('Failed to fetch withdrawals: $error');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      print('❌ Exception in fetchAllWithdrawals: $e');
      throw Exception('Failed to fetch withdrawals: $e');
    }
  }

  static Future<List<WithdrawalRequest>> fetchUserWithdrawals(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/user/user_withdrawals?userId=$userId');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> rawList = data['withdrawals'];
        return rawList.map((e) => WithdrawalRequest.fromJson(e)).toList();
      } else {
        final body = jsonDecode(response.body);
        final error = body['error'] ?? 'Unknown error';
        throw Exception('Failed to fetch withdrawals: $error');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      print('❌ Exception in fetchUserWithdrawals: $e');
      throw Exception('Failed to fetch withdrawals: $e');
    }
  }

  static Future<(bool, String)> approveWithdrawal({
    required String jwtToken,
    required String requestId,
    required String utrNumber,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/user/withdrawals/approve'),
        headers: {'Authorization': 'Bearer $jwtToken','Content-Type': 'application/json'},
        body: jsonEncode({'id': requestId, 'utrNumber': utrNumber}),
      ).timeout(Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return (true, data['message']?.toString() ?? 'Withdrawal approved');
      } else {
        return (false, data['error']?.toString() ?? 'Failed to approve');
      }
    } on TimeoutException {
    // 🔌 API took too long
    throw Exception(
    'Request timed out. Please check your connection or try again later.');
    }  catch (e) {
      return (false, 'Error: ${e.toString()}');
  }
  }

  static Future<(bool, String)> rejectWithdrawal({
    required String jwtToken,
    required String requestId,
    required String reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/user/withdrawals/reject'),
        headers: {'Authorization': 'Bearer $jwtToken','Content-Type': 'application/json'},
        body: jsonEncode({'id': requestId, 'reason': reason}),
      ).timeout(Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return (true, (data['message']?.toString() ?? 'Withdrawal rejected'));
    } else {
    return (false, (data['error']?.toString() ?? 'Failed to reject'));
    }
    } on TimeoutException {
    // 🔌 API took too long
    throw Exception(
    'Request timed out. Please check your connection or try again later.');
    }  catch (e) {
    return (false, 'Error: ${e.toString()}');
    }
  }

}
