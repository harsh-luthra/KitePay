import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models/WithdrawalRequest.dart';

class WithdrawService {
  static const String apiUrl = 'http://46.202.164.198:3000/api';

  static Future<bool> submitWithdrawRequest(WithdrawalRequest request) async {
    final Map<String, dynamic> body = {
      'userId': request.userId,
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
      Uri.parse('$apiUrl/user/withdraw'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    } else {
      print('❌ Withdrawal request failed: ${response.body}');
      return false;
    }
  }

  static Future<List<WithdrawalRequest>> fetchAllWithdrawals({String? status}) async {
    try {
      final url = status != null
          ? Uri.parse('$apiUrl/user/withdrawals?status=$status')
          : Uri.parse('$apiUrl/user/withdrawals');

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
      print('❌ Exception in fetchAllWithdrawals: $e');
      throw Exception('Failed to fetch withdrawals: $e');
    }
  }

  static Future<List<WithdrawalRequest>> fetchUserWithdrawals(String userId) async {
    try {
      final url = Uri.parse('$apiUrl/user/user_withdrawals?userId=$userId');

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
    required String requestId,
    required String utrNumber,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/user/withdrawals/approve'),
        headers: {'Content-Type': 'application/json'},
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
    required String requestId,
    required String reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/user/withdrawals/reject'),
        headers: {'Content-Type': 'application/json'},
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
