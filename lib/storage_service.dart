import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'AppWriteService.dart';

class StorageService {
  final _storage = AppwriteService().storage;

  static const String bucketId = 'qr-codes-bucket'; // Your bucket ID

  Future<models.File> uploadQrCodeFile(File file, String qrId) async {
    return await _storage.createFile(
      bucketId: bucketId,
      fileId: qrId,
      file: InputFile.fromPath(path: file.path, filename: file.uri.pathSegments.last),
    );
  }

  Future<String> getQrFileUrl(String fileId) {
    return Future.value(
        'https://cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$fileId/view?project=${AppwriteService.projectId}'
    );
  }
}
