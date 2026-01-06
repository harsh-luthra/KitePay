// WithdrawalAccountsService - Matches your withdrawal_accounts Node.js API
import 'package:admin_qr_manager/models/WithdrawalAccount.dart'; // Create this model
import 'AppConfig.dart';
import 'AppConstants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WithdrawalAccountsService {

  static final String _baseUrl = AppConstants.baseApiUrl;

  // ✅ LIST user's accounts (paginated)
  static Future<PaginatedWithdrawalAccounts> fetchWithdrawalAccountsPaginated({
    required String jwtToken,
    String? cursor,
  }) async {
    final params = <String, String>{'limit': '25'};
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/withdrawal-accounts/withdrawal_accounts').replace(queryParameters: params);
    final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $jwtToken'}
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return PaginatedWithdrawalAccounts(
        accounts: (data['accounts'] as List)
            .map((a) => WithdrawalAccount.fromJson(a))
            .toList(),
        nextCursor: data['nextCursor'],
        total: data['total'],
      );
    }
    throw Exception('Failed: ${resp.statusCode}');
  }

  // ✅ CREATE new account
  static Future<WithdrawalAccount> createWithdrawalAccount({
    required String jwtToken,
    required WithdrawalAccount account,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/withdrawal-accounts/withdrawal_accounts'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(account.toJson()),
    );

    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      return WithdrawalAccount.fromJson(data['account']);
    }
    throw Exception('Create failed: ${resp.statusCode} - ${resp.body}');
  }

  // ✅ UPDATE existing account
  static Future<WithdrawalAccount> updateWithdrawalAccount({
    required String jwtToken,
    required String accountId,
    required Map<String, dynamic> updates, // Partial: {"holderName": "..."}
  }) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/withdrawal-accounts/withdrawal_accounts/$accountId'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(updates),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return WithdrawalAccount.fromJson(data['account']);
    }
    throw Exception('Update failed: ${resp.statusCode}');
  }

  // ✅ DELETE account
  static Future<bool> deleteWithdrawalAccount({
    required String jwtToken,
    required String accountId,
  }) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/withdrawal-accounts/withdrawal_accounts/$accountId'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );
    if (resp.statusCode == 200) return true;
    throw Exception('Delete failed: ${resp.statusCode}');
  }
}

// Models (create models/WithdrawalAccount.dart)
class PaginatedWithdrawalAccounts {
  final List<WithdrawalAccount> accounts;
  final String? nextCursor;
  final int total;
  PaginatedWithdrawalAccounts({
    required this.accounts,
    this.nextCursor,
    required this.total,
  });
}