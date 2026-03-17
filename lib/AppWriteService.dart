import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      debugPrint("User is logged in: ${user.email}");
      return true;
    } on AppwriteException catch (e) {
      debugPrint("User is not logged in: ${e.message}");
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
  Future<String> getJWT() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final cachedJwt = prefs.getString(_jwtKey);
      final expiryMillis = prefs.getInt(_jwtExpiryKey);

      if (cachedJwt != null &&
          expiryMillis != null &&
          _isTokenStillValid(cachedJwt, expiryMillis)) {
        return cachedJwt;
      }
    } catch (_) {
      // Corrupted cache — fall through to generate a fresh token
    }

    return _fetchAndCacheNewJWT(prefs);
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

  Future<String> _fetchAndCacheNewJWT(SharedPreferences prefs) async {
    try {
      final jwtResponse = await account.createJWT();
      final newJwt = jwtResponse.jwt;

      // Appwrite JWTs live for 15 min — cache with a 2-min safety buffer
      final expiry = DateTime.now()
          .add(Duration(minutes: 15 - _expiryBufferMinutes))
          .millisecondsSinceEpoch;

      await prefs.setString(_jwtKey, newJwt);
      await prefs.setInt(_jwtExpiryKey, expiry);

      return newJwt;
    } catch (e) {
      // Clean up stale cache so the next call tries again fresh
      await prefs.remove(_jwtKey);
      await prefs.remove(_jwtExpiryKey);
      throw Exception('JWT creation failed: $e');
    }
  }

  /// Call this on logout to wipe the cached token.
  Future<void> clearJWT() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_jwtExpiryKey);
  }
}