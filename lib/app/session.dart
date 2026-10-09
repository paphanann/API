import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../core/api.dart';
import '../models/user.dart';

/// ล็อกอินผ่าน Backend ที่ตรวจจากฐานข้อมูล 
class Session extends ChangeNotifier {
  Session() {
    instance = this;
    final s = web.window.localStorage;
    loggedIn = s.getItem('pass_logged_in') == '1';
    email = s.getItem('pass_email') ?? '';
    name = s.getItem('pass_name') ?? 'User';
    if (name.isEmpty) name = 'User';
    role = s.getItem('pass_role') ?? '';
    final saved = s.getItem('pass_auth') ?? '';
    if (saved.isNotEmpty) Api.token = saved;
    if (loggedIn) {
      Future.microtask(resolveRole);
    }
  }

  static late Session instance;

  bool loggedIn = false;
  bool loading = false;
  String email = '';
  String name = 'User';
  String role = '';
  String? lastError;

  bool get isUserRole => role.trim().toLowerCase() == 'user';

  String get homePath => isUserRole ? '/' : '/connections';

  bool allowsPath(String loc) {
    if (!isUserRole) return true;
    return loc != '/connections' &&
        loc != '/integration' &&
        !loc.startsWith('/connections/') &&
        !loc.startsWith('/integration/') &&
        !loc.startsWith('/sync-log') &&
        !loc.startsWith('/settings');
  }

  void _persist() {
    final s = web.window.localStorage;
    if (loggedIn) {
      s.setItem('pass_logged_in', '1');
      s.setItem('pass_email', email);
      s.setItem('pass_name', name);
      s.setItem('pass_role', role);
      if (Api.token != null && Api.token!.isNotEmpty) {
        s.setItem('pass_auth', Api.token!);
      }
    } else {
      s.removeItem('pass_logged_in');
      s.removeItem('pass_email');
      s.removeItem('pass_name');
      s.removeItem('pass_role');
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
      role = user.role;
      Api.token = user.token.isEmpty || user.token == '-' ? null : user.token;
      if (role.isEmpty) role = Api.roleFromToken(Api.token);
      if (role.isEmpty) {
        role = await Api.lookupRole(identities: [this.email, name, email.trim()]);
      }
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

  Future<void> resolveRole() async {
    if (!loggedIn) return;
    try {
      final users = await Api.getUsers();
      if (syncFromUsers(users)) return;
    } catch (_) {}

    var next = role.trim();
    if (next.isEmpty) next = Api.roleFromToken(Api.token);
    if (next.isEmpty) {
      next = await Api.lookupRole(identities: [email, name]);
    }
    if (next.isEmpty || next == role) return;
    role = next;
    _persist();
    notifyListeners();
  }

  /// ชื่อมุมขวาบนให้ตรงกับแถวผู้ใช้ในตาราง ตามอีเมลที่ล็อกอินอยู่
  bool syncFromUsers(List<StaffUser> users) {
    if (!loggedIn) return false;
    final emailKey = email.trim().toLowerCase();
    final nameKey = name.trim().toLowerCase();
    StaffUser? match;
    if (emailKey.isNotEmpty && emailKey != '-') {
      for (final user in users) {
        final mail = user.email.trim().toLowerCase();
        final id = user.id.trim().toLowerCase();
        if (mail == emailKey || id == emailKey) {
          match = user;
          break;
        }
      }
    }
    if (match == null && nameKey.isNotEmpty && nameKey != '-') {
      for (final user in users) {
        if (user.name.trim().toLowerCase() == nameKey) {
          match = user;
          break;
        }
      }
    }
    if (match == null) {
      final roleKey = role.trim().toLowerCase();
      final sameRole = [
        for (final user in users)
          if (user.role.trim().toLowerCase() == roleKey && roleKey.isNotEmpty) user,
      ];
      final nameInList = users.any((user) => user.name.trim().toLowerCase() == nameKey);
      if (!nameInList && sameRole.length == 1) match = sameRole.first;
    }
    if (match == null) return false;

    var changed = false;
    final nextName = match.name.trim();
    if (nextName.isNotEmpty && nextName != '-' && nextName != name) {
      name = nextName;
      changed = true;
    }
    final nextRole = match.role.trim();
    if (nextRole.isNotEmpty && nextRole != '-' && nextRole.toLowerCase() != role.toLowerCase()) {
      role = nextRole;
      changed = true;
    }
    if (!changed) return false;
    _persist();
    notifyListeners();
    return true;
  }

  void logout() {
    loggedIn = false;
    role = '';
    _persist();
    notifyListeners();
  }
}
