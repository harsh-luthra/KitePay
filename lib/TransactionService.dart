import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models/Transaction.dart';

class TransactionService {
  static const String baseUrl = 'http://46.202.164.198:3000/api'; // replace with your real URL

  static Future<List<Transaction>> fetchTransactions({String? userId, String? qrId, required String jwtToken}) async {
    // print("USER_ID: $userId , QR_ID: $qrId");
    try {
      String url = '$baseUrl/admin/transactions';
      Map<String, String> queryParams = {};

      if (userId != null) queryParams['userId'] = userId;
      if (qrId != null) queryParams['qrId'] = qrId;

      if (queryParams.isNotEmpty) {
        url += '?' + Uri(queryParameters: queryParams).query;
      }

      // final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5)); // ⏱️ Set timeout here
      // print(response.body);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List data = responseData['transactions']; // ✅ FIXED
        return data.map((e) => Transaction.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load transactions: ${response.body}');
      }
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    }  catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  static Future<List<Transaction>> fetchUserTransactions({
    required String userId,
    String? qrId,
    required String jwtToken,
  }) async {
    try {
      // Base URL for user transactions
      String url = '$baseUrl/admin/user/transactions';

      // Always include userId, qrId optional
      Map<String, String> queryParams = {'userId': userId};
      if (qrId != null) queryParams['qrId'] = qrId;

      url += '?' + Uri(queryParameters: queryParams).query;

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List data = responseData['transactions'];
        return data.map((e) => Transaction.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load transactions: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      print('❌ Error fetching transactions (user): $e');
      return [];
    }
  }

}
