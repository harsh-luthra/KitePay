import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'AppConstants.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';
import 'package:appwrite/appwrite.dart';

late final Client _client;

class QrCodeService {
  // Base URL for your Node.js backend
  static final String _baseUrl = AppConstants.baseApiUrl;

  // Appwrite client and storage
  final Client _appwriteClient = Client()
      .setEndpoint('https://fra.cloud.appwrite.io/v1') // Your Appwrite Endpoint
      .setProject('688c98fd002bfe3cf596'); // Your project ID

  final String bucketId = "688d2517002810ac532b";

  late final Storage _appwriteStorage;

  QrCodeService() {
    _appwriteStorage = Storage(_appwriteClient);
  }

  /// Call this only if user is logged in
  void setSession(String jwt) {
    _client.setJWT(jwt);
  }

// Function to create the QR code entry in the database via the Node.js server
  Future<bool> _createQrEntryOnServer({
    required String qrId,
    required String fileId,
    required String imageUrl,
    required String jwtToken,
  }) async {
    try {
      print('Attempting to create QR entry on server...');
      final response = await http.post(
        Uri.parse('$_baseUrl/create-qr-entry'), // New endpoint for this purpose
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'qrId': qrId,
          'fileId': fileId,
          'imageUrl': imageUrl,
          'createdAt': DateTime.now().toIso8601String(), // New field for creation time
        }),
      ).timeout(Duration(seconds: 10));

      print('Server response status code: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Successfully created QR entry on server.');
        return true;
      } else {
        print('❌ Failed to create QR entry on server. Expected status 201, but got ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('❌ Error creating QR entry on server: $e');
      return false;
    }
  }

  // The main function to orchestrate the two-step upload and creation process
  // This now handles both file upload and database entry creation.
  Future<bool> uploadQrCode(PlatformFile file, String qrId, String jwtToken) async {
    try {
      // print('Attempting to upload file: ${file.name} to Appwrite...');
      // print('Using bucketId: $bucketId');

      if (file.bytes == null) {
        print('❌ Error: File bytes are null. Cannot proceed with upload.');
        return false;
      }

      // Step 1: Upload the file to Appwrite and get the file ID
      final inputFile = InputFile.fromBytes(
        bytes: file.bytes!,
        filename: file.name,
      );

      final fileResult = await _appwriteStorage.createFile(
        bucketId: bucketId, // Your bucket ID
        fileId: ID.unique(), // Let Appwrite generate a unique ID
        file: inputFile,
      );

      // Check if file upload was successful
      final fileId = fileResult.$id;
      if (fileId.isEmpty) {
        print('❌ Failed to get a file ID from Appwrite after upload.');
        return false;
      }else{
        print('✅ Successfully uploaded file to Appwrite. File ID: $fileId');
      }

      // Step 2: Construct the image URL
      final imageUrl = 'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$fileId/view?project=688c98fd002bfe3cf596';

      // Step 3: Send the QR entry details to the Node.js server
      return await _createQrEntryOnServer(
        qrId: qrId,
        fileId: fileId,
        imageUrl: imageUrl,
        jwtToken: jwtToken,
      );

    } on AppwriteException catch (e) {
      print('❌ Appwrite Error uploading file: ${e.message}');
      print('Appwrite Error type: ${e.type}');
      return false;
    } catch (e) {
      print('❌ General Error during QR code upload and creation: $e');
      return false;
    }
  }

  // Function to fetch all QR codes from the server
  // This function assumes a protected API endpoint that returns a list of QR codes.
  // Your server-side logic should query Appwrite's 'qr_codes' collection and return the data.
  Future<List<QrCode>> getQrCodes(String? jwtToken) async {
    // A simple check to prevent making calls without a token
    if (jwtToken == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/qr-codes'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        // print(response.body);
        List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => QrCode.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load QR codes from the server');
      }
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error fetching QR codes: $e');
      return []; // Return an empty list on error
    }
  }

  Future<List<QrCode>> getUserQrCodes(String userId, String? jwtToken) async {
    if (userId.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/qr-codes/user/$userId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        // print(response.body);
        return jsonList.map((json) => QrCode.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user QR codes from the server');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error fetching user QR codes: $e');
      return [];
    }
  }

  Future<List<QrCode>> getUserAssignedQrCodes(String userId, String? jwtToken) async {
    if (userId.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/qr-codes/user_assigned/$userId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        // print(response.body);
        return jsonList.map((json) => QrCode.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user QR codes from the server');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error fetching user QR codes: $e');
      return [];
    }
  }


  // Function to toggle the 'isActive' status
  // Your server will handle updating the boolean field in the Appwrite database.
  Future<bool> toggleQrCodeStatus(String qrId, bool newStatus, String jwtToken) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/toggle-qr-status/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isActive': newStatus}),
      ).timeout(Duration(seconds: 10));
      return response.statusCode == 200;
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error toggling status: $e');
      return false;
    }
  }

  // Function to assign a user to a QR code
  // This uses a PUT request, which is semantically correct for updating a resource.
  Future<bool> assignQrCode(String qrId, String fileId, String userId, String jwtToken) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/assign-qr/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'assignedUserId': userId,
          'fileId' : fileId
        }),

      ).timeout(Duration(seconds: 10));
      return response.statusCode == 200;
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error assigning user: $e');
      return false;
    }
  }

  // Function to delete a QR code
  // Your server will receive this request, delete the corresponding Appwrite file,
  // and then delete the document from the 'qr_codes' collection.
  Future<bool> deleteQrCode(String qrId, String jwtToken) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete-qr/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(Duration(seconds: 10));
      return response.statusCode == 200;
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error deleting QR code: $e');
      return false;
    }
  }

  Future<bool> createUserQrCode(String userId, String jwtToken) async {
    if (userId.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create-qr/$userId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
          // Add auth headers if needed
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // print(response.body);
        // If your backend returns the QR info directly
        return true;
      } else {
        throw Exception(
            'Failed to create QR code. Status: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error creating user QR code: $e');
      return false;
    }
  }

  Future<bool> createAdminQrCode(String userId, String jwtToken) async {
    if (userId.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create-admin-qr/$userId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
          // Add auth headers if needed
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(response.body);
        // If your backend returns the QR info directly
        return true;
      } else {
        throw Exception('Failed to create QR code. Status: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      print('Error creating user QR code: $e');
      return false;
    }
  }


}
