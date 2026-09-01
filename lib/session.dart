import 'package:flutter/foundation.dart';

/// เดโม่ไว้ก่อน ยังไม่ต่อ auth จริง — กรอกอะไรก็เข้าได้
class Session extends ChangeNotifier {
  bool loggedIn = false;
  bool loading = false;
  String email = '';
  String name = 'User';

  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return false;

    loading = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 350));

    loggedIn = true;
    this.email = email.trim();
    final local = this.email.split('@').first;
    name = local.isEmpty ? 'User' : '${local[0].toUpperCase()}${local.substring(1)}';
    loading = false;
    notifyListeners();
    return true;
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }
}
