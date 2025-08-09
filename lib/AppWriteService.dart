import 'package:appwrite/appwrite.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  /// Replace with your Appwrite values
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1'; // or your self-hosted URL
  static const String projectId = '688c98fd002bfe3cf596';

  factory AppwriteService() {
    return _instance;
  }

  AppwriteService._internal() {
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

  /// Get JWT if already logged in
  Future<String> getJWT() async {
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
