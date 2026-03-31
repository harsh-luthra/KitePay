import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'AppConstants.dart';
import 'models/QrCode.dart';
import 'package:appwrite/appwrite.dart';

class QrCodeService {
  static final String _baseUrl = AppConstants.baseApiUrl;

  final Client _appwriteClient = Client()
      .setEndpoint(AppConstants.appwriteEndpoint)
      .setProject(AppConstants.appwriteProjectId);

  final String bucketId = AppConstants.appwriteBucketId;

  late final Storage _appwriteStorage;

  QrCodeService() {
    _appwriteStorage = Storage(_appwriteClient);
  }

  void setSession(String jwt) {
    _appwriteClient.setJWT(jwt);
  }

// Function to create the QR code entry in the database via the Node.js server
  Future<bool> _createQrEntryOnServer({
    required String qrId,
    required String qrType,
    required String fileId,
    required String imageUrl,
    required String jwtToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create-qr-entry'), // New endpoint for this purpose
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'qrId': qrId,
          'qrType': qrType,
          'fileId': fileId,
          'imageUrl': imageUrl,
          'createdAt': DateTime.now().toIso8601String(), // New field for creation time
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } on TimeoutException {
      // 🔌 API took too long
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return false;
    }
  }

  // The main function to orchestrate the two-step upload and creation process
  // This now handles both file upload and database entry creation.
  Future<bool> uploadQrCode(PlatformFile file, String qrId, String qrType, String jwtToken) async {
    try {
      if (file.bytes == null) {
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
        return false;
      }

      // Step 2: Construct the image URL
      final imageUrl = AppConstants.appwriteFileViewUrl(bucketId, fileId);

      // Step 3: Send the QR entry details to the Node.js server
      return await _createQrEntryOnServer(
        qrId: qrId,
        qrType: qrType,
        fileId: fileId,
        imageUrl: imageUrl,
        jwtToken: jwtToken,
      );

    } on AppwriteException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editQrCodeFile(PlatformFile? file, String qrId, String jwtToken) async {
    try {

      // Step 1: If new file provided, upload it first
      String? newFileId;
      String? newImageUrl;

      if (file != null && file.bytes != null) {
        final inputFile = InputFile.fromBytes(
          bytes: file.bytes!,
          filename: file.name,
        );

        final fileResult = await _appwriteStorage.createFile(
          bucketId: bucketId,
          fileId: ID.unique(),
          file: inputFile,
        );

        newFileId = fileResult.$id;
        if (newFileId.isEmpty) return false;

        newImageUrl = AppConstants.appwriteFileViewUrl(bucketId, newFileId);
      }

      final updateData = <String, dynamic>{};

      // Include file info only if new file was uploaded
      if (newFileId != null) {
        updateData['fileId'] = newFileId;
        updateData['imageUrl'] = newImageUrl!;
      }

      if (updateData.isEmpty) {
        return false;
      }

      // Step 3: Call server PATCH endpoint
      final success = await _editQrEntryOnServer(
        qrId: qrId,
        updateData: updateData,
        jwtToken: jwtToken,
      );

      return success;

    } on AppwriteException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _editQrEntryOnServer({
    required String qrId,
    required Map<String, dynamic> updateData,
    required String jwtToken,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/edit-qr/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      ).timeout(const Duration(seconds: 20));

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
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
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.map((j) => QrCode.fromJson(j)).toList();
        }
        final List data = body['qrCodes'] ?? [];
        return data.map((j) => QrCode.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load QR codes from the server');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return [];
    }
  }

  /// Fetches ALL QR codes by looping through paginated responses.
  Future<List<QrCode>> getAllQrCodes({required String jwtToken}) async {
    final List<QrCode> all = [];
    String? cursor;
    do {
      final page = await getQrCodesPaginated(
        jwtToken: jwtToken,
        cursor: cursor,
        limit: 100,
      );
      all.addAll(page.qrCodes);
      cursor = page.nextCursor;
    } while (cursor != null);
    return all;
  }

  Future<PaginatedQrCodes> getQrCodesPaginated({
    String? cursor,
    int limit = 25,
    required String jwtToken,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (cursor != null) params['cursor'] = cursor;

      final uri = Uri.parse('$_baseUrl/qr-codes')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $jwtToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          // Legacy response: plain array, no pagination
          return PaginatedQrCodes(
            qrCodes: body.map((j) => QrCode.fromJson(j)).toList(),
            nextCursor: null,
          );
        }
        final List data = body['qrCodes'] ?? [];
        return PaginatedQrCodes(
          qrCodes: data.map((j) => QrCode.fromJson(j)).toList(),
          nextCursor: body['nextCursor'],
        );
      } else {
        throw Exception('Failed to load QR codes from the server');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return PaginatedQrCodes(qrCodes: [], nextCursor: null);
    }
  }

  /// Fetches ALL user QR codes by looping through paginated responses.
  Future<List<QrCode>> getAllUserQrCodes({required String userId, required String jwtToken}) async {
    if (userId.isEmpty) return [];
    final List<QrCode> all = [];
    String? cursor;
    do {
      final page = await getUserQrCodesPaginated(
        userId: userId,
        jwtToken: jwtToken,
        cursor: cursor,
        limit: 100,
      );
      all.addAll(page.qrCodes);
      cursor = page.nextCursor;
    } while (cursor != null);
    return all;
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
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.map((j) => QrCode.fromJson(j)).toList();
        }
        final List data = body['qrCodes'] ?? [];
        return data.map((j) => QrCode.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load user QR codes from the server');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return [];
    }
  }

  Future<PaginatedQrCodes> getUserQrCodesPaginated({
    required String userId,
    String? cursor,
    int limit = 25,
    required String jwtToken,
  }) async {
    if (userId.isEmpty) return PaginatedQrCodes(qrCodes: [], nextCursor: null);

    try {
      final params = <String, String>{'limit': limit.toString()};
      if (cursor != null) params['cursor'] = cursor;

      final uri = Uri.parse('$_baseUrl/qr-codes/user/$userId')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $jwtToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return PaginatedQrCodes(
            qrCodes: body.map((j) => QrCode.fromJson(j)).toList(),
            nextCursor: null,
          );
        }
        final List data = body['qrCodes'] ?? [];
        return PaginatedQrCodes(
          qrCodes: data.map((j) => QrCode.fromJson(j)).toList(),
          nextCursor: body['nextCursor'],
        );
      } else {
        throw Exception('Failed to load user QR codes from the server');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return PaginatedQrCodes(qrCodes: [], nextCursor: null);
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
        final body = jsonDecode(response.body);
        if (body is List) {
          return body.map((j) => QrCode.fromJson(j)).toList();
        }
        final List data = body['qrCodes'] ?? [];
        return data.map((j) => QrCode.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load user QR codes from the server');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
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
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return false;
    }
  }

  // Function to assign a user to a QR code
  // This uses a PUT request, which is semantically correct for updating a resource.
  Future<bool> assignQrCodeToUser({
    required String qrId,
    required String assignedUserId, // can be '' for null
    required String fileId,
    required String jwtToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'assignedUserId': assignedUserId,
        'fileId': fileId,
      };

      final response = await http
          .put(
        Uri.parse('$_baseUrl/assign-qr-user/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode == 200;
    } on TimeoutException {
      throw Exception('Request timed out. Please check the connection and try again.');
    } catch (e) {
      return false;
    }
  }

  Future<bool> assignQrCodeManager({
    required String qrId,
    String? managedByUserId,        // pass merchantId only for admin->merchant transfer/assignment
    required String fileId,
    required String jwtToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'managedByUserId': managedByUserId,
        'fileId': fileId,
      };

      final response = await http
          .put(
        Uri.parse('$_baseUrl/assign-qr-manager/$qrId'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } on TimeoutException {
      throw Exception('Request timed out. Please check the connection and try again.');
    } catch (e) {
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
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
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
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Failed to create QR code. Status: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return false;
    }
  }

  /// Manual hold/release on a QR
  Future<Map<String, dynamic>> manualHoldOnQr({
    required String qrId,
    required int amountPaise,
    required String action, // 'hold' or 'release'
    String? reason,
    required String jwtToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/manual-hold-on-qr'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'qrId': qrId,
          'amountPaise': amountPaise,
          'action': action,
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Success', 'record': body['record']};
      } else {
        return {'success': false, 'error': body['error'] ?? 'Failed'};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch manual hold history
  Future<Map<String, dynamic>> getManualHoldHistory({
    String? qrId,
    String? userId,
    String? cursor,
    int limit = 25,
    required String jwtToken,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
      };
      if (qrId != null && qrId.isNotEmpty) params['qrId'] = qrId;
      if (userId != null && userId.isNotEmpty) params['userId'] = userId;
      if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

      final uri = Uri.parse('$_baseUrl/admin/manual-hold-on-qr').replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'records': body['records'] as List<dynamic>? ?? [],
          'total': body['total'] ?? 0,
          'nextCursor': body['nextCursor'],
        };
      } else {
        return {'success': false, 'error': body['error'] ?? 'Failed to fetch'};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to create QR code. Status: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection or try again later.');
    } catch (e) {
      return false;
    }
  }
}

class PaginatedQrCodes {
  final List<QrCode> qrCodes;
  final String? nextCursor;
  PaginatedQrCodes({required this.qrCodes, required this.nextCursor});
}
