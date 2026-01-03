// ApiMerchantsService - API calls matching your Node endpoints
import 'package:admin_qr_manager/models/ApiMerchant.dart';

import 'AppConfig.dart';
import 'AppConstants.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiMerchantsService {

  static final String _baseUrl = AppConstants.baseApiUrl;

  static Future<PaginatedMerchants> fetchApiMerchantsPaginated({
    required String jwtToken,
    String? status,
    String? search,
    String? cursor,
  }) async {
    final params = <String, String>{'limit': '25'};
    if (status != null && status != 'all') params['status'] = status;
    if (search != null) params['search'] = search;
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/merchant/admin/merchants').replace(queryParameters: params);
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $jwtToken'});

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return PaginatedMerchants(
        merchants: (data['merchants'] as List).map((m) => ApiMerchant.fromJson(m)).toList(),
        nextCursor: data['cursor'],
      );
    }
    throw Exception('Failed: ${resp.statusCode}');
  }

  static Future<ApiMerchant> createApiMerchant({required String jwtToken, required ApiMerchant merchant}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/merchant/admin/merchants'),
      headers: {'Authorization': 'Bearer $jwtToken', 'Content-Type': 'application/json'},
      body: jsonEncode(merchant.toJson()),
    );
    print(resp.statusCode);
    print(resp.body);
    if (resp.statusCode == 200) return ApiMerchant.fromJson(jsonDecode(resp.body));
    throw Exception('Create failed: ${resp.statusCode}');
  }

  static Future<ApiMerchant> updateApiMerchant({required String jwtToken, required String merchantId, required ApiMerchant merchant}) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/merchant/admin/merchants/$merchantId'),
      headers: {'Authorization': 'Bearer $jwtToken', 'Content-Type': 'application/json'},
      body: jsonEncode(merchant.toJson()),
    );
    if (resp.statusCode == 200) return ApiMerchant.fromJson(jsonDecode(resp.body)['merchant']);
    throw Exception('Update failed: ${resp.statusCode}');
  }

  static Future<Map<String, dynamic>> toggleMerchantStatus({
    required String jwtToken,
    required String merchantId,
  }) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/merchant/admin/merchants/$merchantId/toggle'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Toggle failed: ${resp.statusCode}');
  }

  static Future<bool> deleteApiMerchant({required String jwtToken, required String merchantId}) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/merchant/admin/merchants/$merchantId'),
      headers: {'Authorization': 'Bearer $jwtToken'},
    );
    if (resp.statusCode == 200) return true;
    throw Exception('Delete failed: ${resp.statusCode}');
  }
}

// Models
class PaginatedMerchants {
  final List<ApiMerchant> merchants;
  final String? nextCursor;
  PaginatedMerchants({required this.merchants, this.nextCursor});
}

// class Merchant {
//   final String? id;
//   final String merchantId;
//   final String name;
//   final String email;
//   final String vpa;
//   final String status;
//   final int? dailyLimit;
//   final String? createdAt;
//   final String? lastLogin;
//
//   Merchant({
//     this.id,
//     required this.merchantId,
//     required this.name,
//     required this.email,
//     required this.vpa,
//     required this.status,
//     this.dailyLimit,
//     this.createdAt,
//     this.lastLogin,
//   });
//
//   factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
//     id: json['id'],
//     merchantId: json['merchantId'] ?? '',
//     name: json['name'] ?? '',
//     email: json['email'] ?? '',
//     vpa: json['vpa'] ?? '',
//     status: json['status'] ?? 'unknown',
//     dailyLimit: json['dailyLimit'],
//     createdAt: json['createdAt'],
//     lastLogin: json['lastLogin'],
//   );
//
//   Map<String, dynamic> toJson() => {
//     'name': name,
//     'email': email,
//     'vpa': vpa,
//     'status': status,
//     'dailyLimit': dailyLimit,
//   };
// }
