import 'dart:convert';

dynamic pick(Map<String, dynamic> m, List<String> keys) {
  for (final want in keys) {
    for (final e in m.entries) {
      if (e.key.toLowerCase() != want.toLowerCase()) continue;
      final v = e.value;
      if (v == null) continue;
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty || t.toLowerCase() == 'null' || t.toLowerCase() == 'undefined') continue;
      }
      return v;
    }
  }
  return null;
}

String pickStr(Map<String, dynamic> m, List<String> keys, {String or = '-'}) {
  final v = pick(m, keys);
  if (v == null) return or;
  final s = v.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'undefined') return or;
  return s;
}

String pickPlainStr(Map<String, dynamic> m, List<String> keys, {String or = '-'}) {
  for (final want in keys) {
    final v = pick(m, [want]);
    if (v == null || v is Map || v is List) continue;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-' || s.toLowerCase() == 'null' || s.toLowerCase() == 'undefined') continue;
    return s;
  }
  return or;
}

const roleKeys = [
  'Role',
  'role',
  'RoleName',
  'roleName',
  'UserRole',
  'userRole',
  'user_role',
  'Group',
  'group',
  'GroupName',
  'groupName',
  'Permission',
  'permission',
  'RoleCode',
  'roleCode',
];

String pickRole(Map<String, dynamic> m) {
  final v = pick(m, roleKeys);
  if (v is List && v.isNotEmpty) {
    final first = v.first;
    if (first is Map) return pickRole(Map<String, dynamic>.from(first));
    final s = first.toString().trim();
    return (s.isEmpty || s == '-') ? '' : s;
  }
  if (v is Map) return pickRole(Map<String, dynamic>.from(v));
  final s = pickStr(m, roleKeys, or: '');
  return s == '-' ? '' : s;
}

double pickDouble(Map<String, dynamic> m, List<String> keys) {
  final v = pick(m, keys);
  if (v is num) return v.toDouble();
  if (v is Map) {
    return pickDouble(Map<String, dynamic>.from(v), ['price', 'Price', 'amount', 'Amount', 'original_price', 'sale_price', 'current_price']);
  }
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// null = field ไม่ถูกส่งมา
bool? pickBool(Map<String, dynamic> m, List<String> keys) {
  final v = pick(m, keys);
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  if (s.isEmpty || s == '-' || s == 'null') return null;
  if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
  if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
  return null;
}

int pickInt(Map<String, dynamic> m, List<String> keys, {int or = 0}) {
  final v = pick(m, keys);
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? or;
}

/// เวลาจาก API ที่เป็น UTC (ลงท้าย Z) ให้โชว์เป็นเวลาไทย UTC+7
DateTime bangkokWall(DateTime instant) {
  final bkk = instant.toUtc().add(const Duration(hours: 7));
  return DateTime(bkk.year, bkk.month, bkk.day, bkk.hour, bkk.minute, bkk.second, bkk.millisecond);
}

DateTime? pickTime(Map<String, dynamic> m, List<String> keys) {
  final v = pick(m, keys);
  if (v == null) return null;

  if (v is DateTime) {
    if (_isCalendarMidnight(v)) return DateTime(v.year, v.month, v.day);
    return v.isUtc ? bangkokWall(v) : v;
  }

  if (v is num) {
    final n = v.toInt();
    DateTime? dt;
    if (n > 1000000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
    } else if (n > 1000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    }
    if (dt == null) return null;
    if (_isCalendarMidnight(dt)) return DateTime(dt.year, dt.month, dt.day);
    return bangkokWall(dt);
  }

  final raw = v.toString().trim();
  final msJson = RegExp(r'^/Date\((-?\d+)(?:[+-]\d{4})?\)/$').firstMatch(raw);
  if (msJson != null) {
    final dt = DateTime.fromMillisecondsSinceEpoch(int.parse(msJson.group(1)!), isUtc: true);
    if (_isCalendarMidnight(dt)) return DateTime(dt.toUtc().year, dt.toUtc().month, dt.toUtc().day);
    return bangkokWall(dt);
  }

  // ฟิลด์วันที่อย่างเดียว เช่น 2026-11-02 หรือ 2026-11-02T00:00:00Z — อย่าบวก +7 จนเป็น 07:00
  final dateOnly = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ]00:00:00(?:\.\d+)?(?:Z|[+-](?:00:00|07:00))?)?$',
  ).firstMatch(raw);
  if (dateOnly != null) {
    return DateTime(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
  }

  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;

  // Z หรือ +00:00 คือ UTC จริงจากฐานข้อมูล — สตริงที่ไม่มีโซนเป็นเวลาไทยอยู่แล้ว
  final hasOffset = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  if (hasOffset) return bangkokWall(dt);
  return dt;
}

bool _isCalendarMidnight(DateTime t) {
  return t.hour == 0 && t.minute == 0 && t.second == 0;
}

List<dynamic> pickList(Map<String, dynamic> m, List<String> keys) {
  final v = pick(m, keys);
  if (v is List) return v;
  if (v is String) {
    final t = v.trim();
    if (t.startsWith('[')) {
      try {
        final d = jsonDecode(t);
        if (d is List) return d;
      } catch (_) {}
    }
  }
  return const [];
}

Map<String, dynamic>? tryJsonMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    final t = v.trim();
    if (t.startsWith('{')) {
      try {
        final d = jsonDecode(t);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
  }
  return null;
}

String friendlyPublicSummary({
  required String platform,
  Map<String, dynamic>? payload,
  String orderNo = '',
  String fallback = '',
}) {
  if (payload != null) {
    final order = pickStr(payload, [
      'order_sn',
      'orderSn',
      'OrderNo',
      'order_no',
      'order_id',
      'OrderId',
      'MarketplaceOrderId',
      'marketplaceOrderId',
    ], or: orderNo);
    final status = pickStr(payload, ['order_status', 'orderStatus', 'Status', 'status'], or: '');
    final lines = <String>[];
    if (platform.isNotEmpty) lines.add(platform);
    if (order.isNotEmpty && order != '-') lines.add('Order: $order');
    if (status.isNotEmpty && status != '-') lines.add('Status: $status');
    if (lines.length >= 2) return lines.join('\n');
  }

  final text = fallback.trim();
  if (text.isEmpty || text == '-') return '-';
  return redactSecretsInText(text);
}

String redactSecretsInText(String raw) {
  return raw.replaceAllMapped(
    RegExp(
      r'(access_token|refresh_token|token|password|secret|partner_key|api_key|authorization)\s*[:=]\s*("[^"]*"|\S+)',
      caseSensitive: false,
    ),
    (m) => '${m[1]}: ***',
  );
}
