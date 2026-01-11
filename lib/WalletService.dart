import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/Wallet.dart';
import '../models/WalletTransaction.dart';
import 'AppConfig.dart';
import 'AppConstants.dart';

class WalletService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  // ✅ GET wallet balance - Debug friendly
  static Future<Wallet> getBalance({
    required String jwtToken,
    bool debugPrint = true,
  }) async {
    print('🔍 [WalletService] Fetching balance...');
    print('📡 URL: $_baseUrl/wallet/balance');
    print('🔑 Token: ${jwtToken.substring(0, 20)}...');

    final resp = await http.get(
      Uri.parse('$_baseUrl/wallet/balance'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    print('📄 Response: ${resp.body}...');
    print('📊 [WalletService] Balance Response: ${resp.statusCode}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      print('✅ [WalletService] Balance fetched: ${data['balance']}');
      return Wallet.fromJson(data);
    }

    print('❌ [WalletService] Balance failed: ${resp.statusCode}');
    print('📄 Error body: ${resp.body}');
    throw WalletServiceException(
      'Balance fetch failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  // ✅ LIST wallet transactions (paginated) - Debug friendly
  static Future<PaginatedWalletTransactions> getWalletTransactions({
    required String jwtToken,
    String? cursor,
    int limit = 25,
    bool debugPrint = true,
  }) async {
    final params = {'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/wallet/transactions')
        .replace(queryParameters: params);

    if (debugPrint) {
      print('🔍 [WalletService] Fetching transactions...');
      print('📡 URL: $uri');
      print('📄 Params: $params');
      print('🔑 Token: ${jwtToken.substring(0, 20)}...');
    }

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (debugPrint) {
      print('📊 [WalletService] Transactions Response: ${resp.statusCode}');
      print('📄 Response preview: ${jsonDecode(resp.body)['transactions']?.length ?? 0} txns');
    }

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final result = PaginatedWalletTransactions(
        transactions: (data['transactions'] as List)
            .map((t) => WalletTransaction.fromJson(t))
            .toList(),
        nextCursor: data['nextCursor'],
        total: data['total'],
      );
      if (debugPrint) {
        print('✅ [WalletService] Loaded ${result.transactions.length} transactions');
      }
      return result;
    }

    if (debugPrint) {
      print('❌ [WalletService] Transactions failed: ${resp.statusCode}');
      print('📄 Error: ${resp.body}');
    }
    throw WalletServiceException(
      'Transactions fetch failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  // ✅ RECHARGE - Generate QR for payment
  static Future<WalletRechargeResponse> recharge({
    required String jwtToken,
    required double amount,
    bool debugPrint = true,
  }) async {
    if (debugPrint) {
      print('💰 [WalletService] Initiating recharge: ₹$amount');
      print('📡 URL: $_baseUrl/wallet/recharge');
      print('🔑 Token: ${jwtToken.substring(0, 20)}...');
    }

    final resp = await http.post(
      Uri.parse('$_baseUrl/wallet/recharge'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'amount': amount}),
    );

    if (debugPrint) {
      print('📊 [WalletService] Recharge Response: ${resp.statusCode}');
      print('📄 Response: ${resp.body.substring(0, 200)}...');
    }

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final result = WalletRechargeResponse.fromJson(data);
      if (debugPrint) {
        print('✅ [WalletService] QR generated: ${result.transactionId}');
      }
      return result;
    }

    if (debugPrint) {
      print('❌ [WalletService] Recharge failed: ${resp.statusCode}');
    }
    throw WalletServiceException(
      'Recharge failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  // ✅ CANCEL QR transaction
  static Future<bool> cancelRecharge({
    required String jwtToken,
    required String transactionId,
    bool debugPrint = true,
  }) async {
    if (debugPrint) {
      print('⏹️ [WalletService] Canceling transaction: $transactionId');
      print('📡 URL: $_baseUrl/wallet/transactions/$transactionId/cancel');
    }

    final resp = await http.post(
      Uri.parse('$_baseUrl/wallet/transactions/$transactionId/cancel'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (debugPrint) {
      print('📊 [WalletService] Cancel Response: ${resp.statusCode}');
    }

    if (resp.statusCode == 200) {
      if (debugPrint) print('✅ [WalletService] Transaction cancelled');
      return true;
    }

    if (debugPrint) print('❌ [WalletService] Cancel failed: ${resp.statusCode}');
    throw WalletServiceException(
      'Cancel failed: ${resp.statusCode}',
      statusCode: resp.statusCode,
      responseBody: resp.body,
    );
  }

  // ✅ Additional methods (same pattern)
  static Future<Wallet> createWallet({required String jwtToken, bool debugPrint = true}) async {
    // Similar debug logging...
    throw UnimplementedError('createWallet - implement as needed');
  }

  static Future<Wallet> updateWallet({
    required String jwtToken,
    required String walletId,
    required Map<String, dynamic> updates,
    bool debugPrint = true,
  }) async {
    // Similar debug logging...
    throw UnimplementedError('updateWallet - implement as needed');
  }
}

// ✅ Custom Exception with full details
class WalletServiceException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;
  final DateTime timestamp;

  WalletServiceException(
      this.message, {
        required this.statusCode,
        required this.responseBody,
      }) : timestamp = DateTime.now();

  @override
  String toString() =>
      'WalletServiceException($timestamp)\n'
          'Status: $statusCode\n'
          'Message: $message\n'
          'Response: ${responseBody.substring(0, 500)}...';

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'statusCode': statusCode,
    'message': message,
    'responseBody': responseBody,
  };
}

// ✅ Models (unchanged)
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
