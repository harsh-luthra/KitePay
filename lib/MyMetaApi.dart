import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'AppConstants.dart';
import 'models/AppUser.dart';

class MyMetaApi {
  static const _cacheKey = 'cached_user_meta';
  static final String _baseUrl = AppConstants.baseApiUrl;

  // Fetches from API (GET), caches, and returns AppUser.
  // If refresh == false, tries cache first.
  static Future<AppUser?> getMyMetaData({
    required String jwtToken,
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = await _loadFromCache();
      if (cached != null) return cached;
    }

    final url = Uri.parse('$_baseUrl/admin/getMyMetaData');
    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      final meta = AppUser.fromJson(data);
      await _saveToCache(meta);
      return meta;
    } else {
      // Fallback to cache on server error
      final cached = await _loadFromCache();
      if (cached != null) return cached;
      // Surface error (or return null if preferred)
      throw Exception('Failed to fetch metadata: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> clearCachedMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  static Future<void> _saveToCache(AppUser meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(meta.toJson()));
  }

  static Future<AppUser?> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(raw);
      return AppUser.fromJson(jsonMap);
    } catch (_) {
      // If cache corrupted, clear it
      await prefs.remove(_cacheKey);
      return null;
    }
  }
}