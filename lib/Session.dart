// session.dart
import 'package:admin_qr_manager/models/AppUser.dart';

class Session {
  Session._();
  static final Session instance = Session._();

  String? jwt;
  AppUser? user;

  bool get isLoggedIn => jwt != null && user != null;

  Future<void> initialize({required String jwtToken}) async {
    jwt = jwtToken;
    user = await _fetchUserMeta(jwtToken);
  }

  Future<AppUser> _fetchUserMeta(String jwt) async {
    // TODO: call backend endpoint /me or similar and parse
    // final res = await http.get(... Authorization: Bearer jwt ...);
    // return UserMeta.fromJson(jsonDecode(res.body));
    throw UnimplementedError();
  }

  void clear() {
    jwt = null;
    user = null;
  }
}
