import '../core/json_util.dart';

class StaffUser {
  const StaffUser({
    this.id = '',
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  factory StaffUser.fromApi(Map<String, dynamic> m) {
    final st = pickStr(m, ['Status', 'status', 'Active', 'active'], or: '').toLowerCase();
    final active = pickBool(m, ['Active', 'active', 'Enabled', 'enabled']) ??
        !(st.contains('inactive') || st.contains('disable') || st.contains('off'));
    return StaffUser(
      id: pickStr(m, ['Id', 'id', 'UserId', 'userId', 'UserID'], or: ''),
      name: pickStr(m, ['Name', 'name', 'DisplayName', 'displayName', 'FullName'], or: '-'),
      email: pickStr(m, ['Email', 'email', 'UserName', 'username'], or: '-'),
      role: pickStr(m, ['Role', 'role', 'Group', 'group', 'Permission'], or: '-'),
      active: active,
    );
  }

  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;

  String get apiKey {
    if (id.isNotEmpty && id != '-') return id;
    return email;
  }

  Map<String, dynamic> toJson({String? password}) => {
        if (id.isNotEmpty && id != '-') 'id': id,
        'name': name,
        'email': email,
        'role': role,
        'active': active,
        if (password != null && password.isNotEmpty) 'password': password,
      };
}
