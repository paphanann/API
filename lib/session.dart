import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'api.dart';

/// ล็อกอินผ่าน Backend ที่ตรวจจากฐานข้อมูล — หน้าบ้านไม่คุย SQL ตรง
class Session extends ChangeNotifier {
  Session() {
    final s = web.window.localStorage;
    loggedIn = s.getItem('pass_logged_in') == '1';
    email = s.getItem('pass_email') ?? '';
    name = s.getItem('pass_name') ?? 'User';
    if (name.isEmpty) name = 'User';
    final saved = s.getItem('pass_auth') ?? '';
    if (saved.isNotEmpty) Api.token = saved;
  }

  bool loggedIn = false;
  bool loading = false;
  String email = '';
  String name = 'User';
  String? lastError;

  void _persist() {
    final s = web.window.localStorage;
    if (loggedIn) {
      s.setItem('pass_logged_in', '1');
      s.setItem('pass_email', email);
      s.setItem('pass_name', name);
      if (Api.token != null && Api.token!.isNotEmpty) {
        s.setItem('pass_auth', Api.token!);
      }
    } else {
      s.removeItem('pass_logged_in');
      s.removeItem('pass_email');
      s.removeItem('pass_name');
      s.removeItem('pass_auth');
      Api.token = null;
    }
  }

  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return false;

    loading = true;
    lastError = null;
    notifyListeners();

    try {
      final user = await Api.login(email: email.trim(), password: password);
      loggedIn = true;
      this.email = user.email == '-' || user.email.isEmpty ? email.trim() : user.email;
      if (user.name.isNotEmpty && user.name != '-') {
        name = user.name;
      } else {
        final local = this.email.split('@').first;
        name = local.isEmpty ? 'User' : '${local[0].toUpperCase()}${local.substring(1)}';
      }
      Api.token = user.token.isEmpty || user.token == '-' ? null : user.token;
      _persist();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void logout() {
    loggedIn = false;
    _persist();
    notifyListeners();
  }
}
