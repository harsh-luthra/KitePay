import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/Transaction.dart';

class TransactionService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<PaginatedTransactions> fetchTransactions({
    String? userId,
    String? qrId,
    String? cursor,
    int limit = 25,
    DateTime? from,
    DateTime? to,
    required String jwtToken
  }) async {
    try {
      String url = '$_baseUrl/admin/transactions';
      Map<String, String> queryParams = {
        'limit': limit.toString(),
      };

      if (userId != null) queryParams['userId'] = userId;
      if (qrId != null) queryParams['qrId'] = qrId;
      if (cursor != null) queryParams['cursor'] = cursor;
      if (from != null) queryParams['from'] = _formatDate(from);
      if (to != null) queryParams['to'] = _formatDate(to);

      url += '?' + Uri(queryParameters: queryParams).query;

      // print(url);

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
        final String? nextCursor = responseData['nextCursor'];

        return PaginatedTransactions(
          transactions: data.map((e) => Transaction.fromJson(e)).toList(),
          nextCursor: nextCursor,
        );
      } else {
        throw Exception('Failed to load transactions: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      print('Error fetching transactions: $e');
      return PaginatedTransactions(transactions: [], nextCursor: null);
    }
  }

  // String url = '$_baseUrl/admin/user/transactions';

  static Future<PaginatedTransactions> fetchUserTransactions({
    String? userId,
    String? qrId,
    DateTime? from,
    DateTime? to,
    String? cursor,
    int limit = 25,
    required String jwtToken
  }) async {
    try {
      String url = '$_baseUrl/admin/user/transactions';
      Map<String, String> queryParams = {
        'limit': limit.toString(),
      };

      if (userId != null) queryParams['userId'] = userId;
      if (qrId != null) queryParams['qrId'] = qrId;
      if (cursor != null) queryParams['cursor'] = cursor;
      if (from != null) queryParams['from'] = _formatDate(from);
      if (to != null) queryParams['to'] = _formatDate(to);

      url += '?${Uri(queryParameters: queryParams).query}';

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
        final String? nextCursor = responseData['nextCursor'];

        print('NextCursor : $nextCursor');

        return PaginatedTransactions(
          transactions: data.map((e) => Transaction.fromJson(e)).toList(),
          nextCursor: nextCursor,
        );
      } else {
        throw Exception('Failed to load user transactions: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection.');
    } catch (e) {
      print('Error fetching user transactions: $e');
      return PaginatedTransactions(transactions: [], nextCursor: null);
    }
  }

  static String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

}

class PaginatedTransactions {
  final List<Transaction> transactions;
  final String? nextCursor;
  PaginatedTransactions({required this.transactions, required this.nextCursor});
}
