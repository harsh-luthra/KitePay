import 'package:appwrite/appwrite.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppWriteService {
  static final AppWriteService _instance = AppWriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  /// Replace with your Appwrite values
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1'; // or your self-hosted URL
  static const String projectId = '688c98fd002bfe3cf596';

// Define a key for your JWT in SharedPreferences
  static const String jwtKey = 'appwrite_jwt';

  factory AppWriteService() {
    return _instance;
  }

  AppWriteService._internal() {
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId)
        .setSelfSigned(status: true); // Only use true for development/self-hosted

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
  }

  Future<bool> isLoggedIn() async {
    try {
      final user = await account.get();
      print("User is logged in: ${user.email}");
      return true;
    } on AppwriteException catch (e) {
      print("User is not logged in: ${e.message}");
      return false;
    }
  }


  // Get or create a JWT.
  /// It will first try to retrieve a cached JWT from SharedPreferences.
  /// If the JWT is expired or doesn't exist, it will create a new one and cache it.
  Future<String> getJWT() async {
    try {
      // SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      final cachedJwt = prefs.getString(jwtKey);

      // Check if a JWT is cached and if it's still valid
      if (cachedJwt != null && !JwtDecoder.isExpired(cachedJwt)) {
        // print('Using cached JWT');
        return cachedJwt;
      }

      // If no JWT is cached or it's expired, create a new one
      // print('Generating new JWT');
      final jwtResponse = await account.createJWT();
      final newJwt = jwtResponse.jwt;

      // Cache the new JWT for future use
      await prefs.setString(jwtKey, newJwt);

      return newJwt;
    } catch (e) {
      // If an error occurs during API call or any other step,
      // clear the old token and throw an exception.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(jwtKey);
      throw Exception('JWT creation failed: $e');
    }
  }

  /// Get JWT if already logged in
  Future<String> getJWT_Old() async {
    try {
      final jwt = await account.createJWT();
      return jwt.jwt;
    } catch (e) {
      throw Exception('JWT creation failed: $e');
    }
  }

  /// Get a valid JWT, refreshing only after 13 minutes.
  // Future<String> getJWT(Account account) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final now = DateTime.now();
  //
  //   final cachedJwt = prefs.getString(_jwtKey);
  //   final expiryMillis = prefs.getInt(_expiryKey);
  //   final expiry = expiryMillis != null ? DateTime.fromMillisecondsSinceEpoch(expiryMillis) : null;
  //
  //   if (cachedJwt != null && expiry != null && now.isBefore(expiry)) {
  //     // Return cached token if still valid
  //     return cachedJwt;
  //   }
  //
  //   // Else create new JWT
  //   try {
  //     final jwtResponse = await account.createJWT();
  //     final jwt = jwtResponse.jwt;
  //
  //     // Set expiry to 13 minutes from now (JWT is valid for 15)
  //     final newExpiry = now.add(const Duration(minutes: 13));
  //
  //     // Save to SharedPreferences
  //     await prefs.setString(_jwtKey, jwt);
  //     await prefs.setInt(_expiryKey, newExpiry.millisecondsSinceEpoch);
  //
  //     return jwt;
  //   } catch (e) {
  //     throw Exception('JWT creation failed: $e');
  //   }
  // }

}
