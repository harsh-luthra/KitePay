import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show rootNavigatorKey;
import 'SplashScreen.dart';

class AppWriteService {
  static final AppWriteService _instance = AppWriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = '688c98fd002bfe3cf596';

  static const String _jwtKey = 'appwrite_jwt';
  static const String _jwtExpiryKey = 'appwrite_jwt_expiry';

  // Refresh 2 minutes before actual expiry to avoid edge cases
  static const int _expiryBufferMinutes = 2;

  // In-memory cache to avoid repeated SharedPreferences reads
  String? _cachedJwt;
  int? _cachedExpiryMillis;

  // Deduplicates concurrent refresh calls
  Future<String>? _pendingRefresh;

  factory AppWriteService() => _instance;

  AppWriteService._internal() {
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
  }

  Future<bool> isLoggedIn() async {
    try {
      final user = await account.get();
      if (kDebugMode) debugPrint("User is logged in: ${user.email}");
      return true;
    } on AppwriteException catch (e) {
      if (kDebugMode) debugPrint("User is not logged in: ${e.message}");
      return false;
    }
  }

  Future<String> getUserId() async {
    try {
      final user = await account.get();
      return user.$id;
    } on AppwriteException {
      return "";
    }
  }

  /// Returns a valid JWT, creating a new one if expired or missing.
  /// Appwrite JWTs are valid for 15 minutes — we refresh 2 minutes early.
  /// Uses in-memory cache first, then SharedPreferences, then network.
  /// Concurrent calls share a single refresh to avoid duplicate API calls.
  Future<String> getJWT() async {
    // 1. Check in-memory cache (no async overhead)
    if (_cachedJwt != null &&
        _cachedExpiryMillis != null &&
        _isTokenStillValid(_cachedJwt!, _cachedExpiryMillis!)) {
      return _cachedJwt!;
    }

    // 2. Check SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJwt = prefs.getString(_jwtKey);
      final expiryMillis = prefs.getInt(_jwtExpiryKey);

      if (storedJwt != null &&
          expiryMillis != null &&
          _isTokenStillValid(storedJwt, expiryMillis)) {
        _cachedJwt = storedJwt;
        _cachedExpiryMillis = expiryMillis;
        return storedJwt;
      }
    } catch (_) {
      // Corrupted cache — fall through to generate a fresh token
    }

    // 3. Refresh from network — deduplicate concurrent calls
    _pendingRefresh ??= _fetchAndCacheNewJWT().whenComplete(() {
      _pendingRefresh = null;
    });
    return _pendingRefresh!;
  }

  /// Checks both the stored expiry timestamp AND the JWT's own claims.
  bool _isTokenStillValid(String jwt, int expiryMillis) {
    final now = DateTime.now();
    final storedExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);

    // Fail fast if our own stored expiry has passed
    if (now.isAfter(storedExpiry)) return false;

    // Double-check the JWT's own expiry claim
    try {
      return !JwtDecoder.isExpired(jwt);
    } catch (_) {
      // Malformed JWT — treat as expired
      return false;
    }
  }

  Future<String> _fetchAndCacheNewJWT() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jwtResponse = await account.createJWT();
      final newJwt = jwtResponse.jwt;

      // Appwrite JWTs live for 15 min — cache with a 2-min safety buffer
      final expiry = DateTime.now()
          .add(Duration(minutes: 15 - _expiryBufferMinutes))
          .millisecondsSinceEpoch;

      await prefs.setString(_jwtKey, newJwt);
      await prefs.setInt(_jwtExpiryKey, expiry);

      // Update in-memory cache
      _cachedJwt = newJwt;
      _cachedExpiryMillis = expiry;

      return newJwt;
    } on AppwriteException catch (e) {
      // Session expired (401) — clear cache and redirect to login
      _cachedJwt = null;
      _cachedExpiryMillis = null;
      await prefs.remove(_jwtKey);
      await prefs.remove(_jwtExpiryKey);

      if (e.code == 401) {
        _redirectToLogin();
      }
      throw Exception('JWT creation failed: $e');
    } catch (e) {
      // Clean up stale cache so the next call tries again fresh
      _cachedJwt = null;
      _cachedExpiryMillis = null;
      await prefs.remove(_jwtKey);
      await prefs.remove(_jwtExpiryKey);
      throw Exception('JWT creation failed: $e');
    }
  }

  void _redirectToLogin() {
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    }
  }

  /// Call this on logout to wipe the cached token.
  Future<void> clearJWT() async {
    _cachedJwt = null;
    _cachedExpiryMillis = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_jwtExpiryKey);
  }
}