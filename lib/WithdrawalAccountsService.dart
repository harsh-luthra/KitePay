import 'package:admin_qr_manager/models/WithdrawalAccount.dart';
import 'AppConstants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WithdrawalAccountsService {

  static final String _baseUrl = AppConstants.baseApiUrl;

  // List user's own accounts (paginated)
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

  // List any user's accounts (paginated, admin)
  static Future<PaginatedWithdrawalAccounts> fetchUserWithdrawalAccountsPaginated({
    required String jwtToken,
    required String userId,
    String? cursor,
  }) async {
    final params = <String, String>{
      'limit': '25',
      'userId': userId,
    };
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/withdrawal-accounts/admin_withdrawal_accounts').replace(queryParameters: params);
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

  // Create own account
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

  // Update own account
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

  // Delete own account
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



  // Create account for a user (admin)
  static Future<WithdrawalAccount> createUserWithdrawalAccount({
    required String jwtToken,
    required String userId,
    required WithdrawalAccount account,
  }) async {

    final body = {
      ...account.toJson(),
      'userId': userId,  // Add to body
    };

    final resp = await http.post(
      Uri.parse('$_baseUrl/withdrawal-accounts/admin_withdrawal_accounts'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      return WithdrawalAccount.fromJson(data['account']);
    }
    throw Exception('Create failed: ${resp.statusCode} - ${resp.body}');
  }

  // Update a user's account (admin)
  static Future<WithdrawalAccount> updateUserWithdrawalAccount({
    required String jwtToken,
    required String userId,
    required String accountId,
    required Map<String, dynamic> updates, // Partial: {"holderName": "..."}
  }) async {

    final resp = await http.put(
      Uri.parse('$_baseUrl/withdrawal-accounts/admin_withdrawal_accounts/$accountId'),
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

  // Delete a user's account (admin)
  static Future<bool> deleteUserWithdrawalAccount({
    required String jwtToken,
    required String userId,
    required String accountId,
  }) async {

    final body = {
      'userId': userId,  // Add to body
    };

    final resp = await http.delete(
      Uri.parse('$_baseUrl/withdrawal-accounts/admin_withdrawal_accounts/$accountId'),
      headers: {'Authorization': 'Bearer $jwtToken'},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) return true;
    throw Exception('Delete failed: ${resp.statusCode}');
  }


}

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