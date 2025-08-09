import 'package:appwrite/models.dart' as models;
import 'package:admin_qr_manager/AppWriteService.dart';

class AuthService {
  final _account = AppwriteService().account;

  Future<models.Session> login(String email, String password) async {
    return await _account.createEmailPasswordSession(email: email, password: password);
  }

  Future<void> logout() async {
    await _account.deleteSessions(); // deletes all sessions
  }

  Future<models.User> getCurrentUser() async {
    return await _account.get();
  }
}
