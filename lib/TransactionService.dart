import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';
import 'models/Transaction.dart';

// Enum used in UI layer
enum TxnStatus { normal, cyber, refund, chargeback }

class TransactionService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<PaginatedTransactions> fetchTransactions({
    String? userId,
    String? qrId,
    DateTime? from,
    DateTime? to,
    String? cursor,
    int limit = 25,
    String? status,
    String? searchField,
    String? searchValue,
    required String jwtToken,
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
      if (status != null) queryParams['status'] = status;

      // Add search query params if specified
      if (searchField != null && searchValue != null) {
        queryParams['searchField'] = searchField;
        queryParams['searchValue'] = searchValue;
      }

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

        // print(data);

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
    String? status,
    String? searchField,
    String? searchValue,
    required String jwtToken,
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
      if (status != null) queryParams['status'] = status;

      // Add search query params if specified
      if (searchField != null && searchValue != null) {
        queryParams['searchField'] = searchField;
        queryParams['searchValue'] = searchValue;
      }

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

        // print('responseData : $responseData');

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

  static Future<bool> uploadManualTransaction({
    required String qrCodeId,
    required String rrnNumber,
    required double amount,
    required String isoDate,
    // String? payload,
    // String? paymentId,
    // String? vpa,
    required String jwtToken,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'qrCodeId': qrCodeId,
        'rrnNumber': rrnNumber,
        'amount': amount,
        'isoDate': isoDate,
      };

      // Optional fields if provided
      // if (payload != null) body['payload'] = payload;
      // if (paymentId != null) body['paymentId'] = paymentId;
      // if (vpa != null) body['vpa'] = vpa;

      final response = await http.post(
        Uri.parse('$_baseUrl/admin/transactions/manual'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', // 👈 attach admin JWT here
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return true;
      } else {
        print('❌ Manual transaction upload failed: ${response.body}');
        throw Exception('${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      print('❌ Manual transaction upload failed: $e');
      throw Exception('❌ Manual transaction upload failed: $e');
    }
  }

  static Future<bool> editTransactionStatus({
    required String id,           // Appwrite $id of the transaction document
    String? status,         // add: plain string e.g. "refund"
    TxnStatus? statusEnum,  // optional: convenience overload to accept enum
    required String jwtToken,
  }) async {
    try {
      final Map<String, dynamic> body = {};

      // Prefer explicit string if both provided; otherwise use enum.name
      if (status != null && status.isNotEmpty) {
        body['status'] = status.toLowerCase(); // backend expects lowercase [21]
      } else if (statusEnum != null) {
        body['status'] = statusEnum.name; // "normal" | "cyber" | ... [6][19]
      }

      if (body.isEmpty) {
        throw Exception('No fields to update');
      }

      final url = Uri.parse('$_baseUrl/admin/transactions/$id/status');

      final response = await http
          .patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        // propagate server error body for context
        throw Exception('Edit failed: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      throw Exception('❌ Edit transaction failed: $e');
    }
  }

  static Future<bool> editTransaction({
    required String id,           // Appwrite $id of the transaction document
    String? qrCodeId,             // optional
    String? rrnNumber,            // optional
    double? amount,               // rupees; backend converts to paise
    String? isoDate,              // ISO-8601 string
    String? status,         // add: plain string e.g. "refund"
    TxnStatus? statusEnum,  // optional: convenience overload to accept enum
    required String jwtToken,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (qrCodeId != null) body['qrCodeId'] = qrCodeId;
      if (rrnNumber != null) body['rrnNumber'] = rrnNumber;
      if (amount != null) body['amount'] = amount;
      if (isoDate != null) body['isoDate'] = isoDate;

      // Prefer explicit string if both provided; otherwise use enum.name
      if (status != null && status.isNotEmpty) {
        body['status'] = status.toLowerCase(); // backend expects lowercase [21]
      } else if (statusEnum != null) {
        body['status'] = statusEnum.name; // "normal" | "cyber" | ... [6][19]
      }

      if (body.isEmpty) {
        throw Exception('No fields to update');
      }

      final url = Uri.parse('$_baseUrl/admin/transactions/$id');

      final response = await http
          .patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        // propagate server error body for context
        throw Exception('Edit failed: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      throw Exception('❌ Edit transaction failed: $e');
    }
  }

  static Future<bool> deleteTransaction({
    required String id,        // Appwrite $id of the transaction
    required String jwtToken,  // admin JWT
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/admin/transactions/$id');

      final resp = await http
          .delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return true;
      } else if (resp.statusCode == 404) {
        throw Exception('Transaction not found');
      } else {
        throw Exception('Delete failed: ${resp.statusCode} ${resp.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection.');
    } catch (e) {
      throw Exception('❌ Delete transaction failed: $e');
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
