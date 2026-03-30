import 'dart:convert';
import 'package:http/http.dart' as http;

import 'AppConstants.dart';

class ConfigItem {
  final String id;
  final String key;
  final String val;
  final String type;
  final String description;
  final String? createdAt;
  final String? updatedAt;

  ConfigItem({
    required this.id,
    required this.key,
    required this.val,
    required this.type,
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  factory ConfigItem.fromJson(Map<String, dynamic> json) {
    return ConfigItem(
      id: json['id'] ?? '',
      key: json['key'] ?? '',
      val: json['val'] ?? '',
      type: json['type'] ?? 'string',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] ?? json['\$createdAt'],
      updatedAt: json['updatedAt'] ?? json['\$updatedAt'],
    );
  }
}

class ConfigService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  static Map<String, String> _headers(String jwtToken) => {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      };

  static Future<List<ConfigItem>> fetchConfigs({
    required String jwtToken,
  }) async {
    final url = '$_baseUrl/admin/config';
    // print('[ConfigService] GET $url');
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(jwtToken),
      ).timeout(const Duration(seconds: 10));

      // print('[ConfigService] Status: ${resp.statusCode}');
      // print('[ConfigService] Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final list = (body['configs'] as List?) ?? [];
        // print('[ConfigService] Parsed ${list.length} configs');
        return list.map((e) => ConfigItem.fromJson(e)).toList();
      } else {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final msg = body['message'] ?? 'Failed to fetch configs';
        // print('[ConfigService] Error response: $msg');
        throw Exception(msg);
      }
    } catch (e) {
      // print('[ConfigService] Exception: $e');
      rethrow;
    }
  }

  static Future<String> createConfig({
    required String jwtToken,
    required String key,
    required String val,
    required String type,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'key': key,
      'val': val,
      'type': type,
    };
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }

    final resp = await http.post(
      Uri.parse('$_baseUrl/admin/config'),
      headers: _headers(jwtToken),
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 10));

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return body['message'] ?? 'Config created';
    } else {
      throw Exception(body['message'] ?? 'Failed to create config');
    }
  }

  static Future<String> updateConfig({
    required String jwtToken,
    required String key,
    String? val,
    String? description,
  }) async {
    final payload = <String, dynamic>{'key': key};
    if (val != null) payload['val'] = val;
    if (description != null) payload['description'] = description;

    final resp = await http.put(
      Uri.parse('$_baseUrl/admin/config'),
      headers: _headers(jwtToken),
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 10));

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) {
      return body['message'] ?? 'Config updated';
    } else {
      throw Exception(body['message'] ?? 'Failed to update config');
    }
  }

  static Future<String> deleteConfig({
    required String jwtToken,
    required String key,
  }) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/admin/config'),
      headers: _headers(jwtToken),
      body: json.encode({'key': key}),
    ).timeout(const Duration(seconds: 10));

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) {
      return body['message'] ?? 'Config deleted';
    } else {
      throw Exception(body['message'] ?? 'Failed to delete config');
    }
  }
}
