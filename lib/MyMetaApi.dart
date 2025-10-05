import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'AppConstants.dart';
import 'models/AppUser.dart';
import 'package:http/http.dart' as http;

class MyMetaApi {
  static const _cacheKey = 'cached_user_meta';
  static AppUser? _inMemory; // serve sync after first load [web:80]

  static Future<void> initFromDisk() async {
    // Call once at app start (e.g., before runApp or in Splash) [web:81]
    _inMemory = await _loadFromCache();
  }

  static AppUser? get current => _inMemory; // sync access everywhere [web:80]

  static Future<AppUser?> getMyMetaData({
    required String jwtToken,
    bool refresh = false,
  }) async {
    // Serve from in-memory if present and not forcing refresh
    if (!refresh && _inMemory != null) return _inMemory; // sync hit next calls [web:80]

    // Try disk cache if not refreshing and memory is empty
    if (!refresh && _inMemory == null) {
      final cached = await _loadFromCache();
      if (cached != null) {
        _inMemory = cached;
        return cached;
      }
    }

    // Fetch network
    final url = Uri.parse('${AppConstants.baseApiUrl}/admin/getMyMetaData');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      // print(res.body);
      final Map<String, dynamic> data = jsonDecode(res.body);
      final meta = AppUser.fromJson(data);
      _inMemory = meta; // warm memory [web:80]
      await _saveToCache(meta);
      return meta;
    }

    // Fallback to disk
    final cached = await _loadFromCache();
    if (cached != null) {
      _inMemory = cached;
      return cached;
    }
    throw Exception('Failed to fetch metadata: ${res.statusCode} ${res.body}');
  }

  static Future<void> clearCachedMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    _inMemory = null; // clear memory too [web:81]
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
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_cacheKey);
      return null;
    }
  }
}
