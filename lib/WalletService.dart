import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:admin_qr_manager/models/Wallet.dart';
import 'package:admin_qr_manager/models/WalletTransaction.dart';
import 'AppConstants.dart';

class WalletService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<Wallet> getBalance({
    required String jwtToken,
  }) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/wallet/balance'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      return Wallet.fromJson(jsonDecode(resp.body));
    }

    throw WalletServiceException(
      'Balance fetch failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  static Future<PaginatedWalletTransactions> getWalletTransactions({
    required String jwtToken,
    String? cursor,
    int limit = 25,
  }) async {
    final params = {'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/wallet/transactions').replace(queryParameters: params);

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return PaginatedWalletTransactions(
        transactions: (data['transactions'] as List)
            .map((t) => WalletTransaction.fromJson(t))
            .toList(),
        nextCursor: data['nextCursor'],
        total: data['total'],
      );
    }

    throw WalletServiceException(
      'Transactions fetch failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  static Future<WalletRechargeResponse> recharge({
    required String jwtToken,
    required double amount,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/wallet/recharge'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (resp.statusCode == 200) {
      return WalletRechargeResponse.fromJson(jsonDecode(resp.body));
    }

    throw WalletServiceException(
      'Recharge failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  static Future<bool> cancelRecharge({
    required String jwtToken,
    required String transactionId,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/wallet/transactions/$transactionId/cancel'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (resp.statusCode == 200) {
      return true;
    }

    throw WalletServiceException(
      'Cancel failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }
}

class WalletServiceException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  WalletServiceException(
      this.message, {
        required this.statusCode,
        required this.responseBody,
      });

  @override
  String toString() =>
      'WalletServiceException: $message (status: $statusCode)';
}

class PaginatedWalletTransactions {
  final List<WalletTransaction> transactions;
  final String? nextCursor;
  final int total;

  PaginatedWalletTransactions({
    required this.transactions,
    this.nextCursor,
    required this.total,
  });
}

class WalletRechargeResponse {
  final String transactionId;
  final String qrBase64;
  final int expirySeconds;
  final String walletId;

  WalletRechargeResponse({
    required this.transactionId,
    required this.qrBase64,
    required this.expirySeconds,
    required this.walletId,
  });

  factory WalletRechargeResponse.fromJson(Map<String, dynamic> json) {
    return WalletRechargeResponse(
      transactionId: json['transactionId'],
      qrBase64: json['qrBase64'],
      expirySeconds: json['expirySeconds'],
      walletId: json['walletId'],
    );
  }
}
