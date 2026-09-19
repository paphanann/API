import 'dart:convert';

dynamic pick(Map<String, dynamic> m, List<String> keys) {
  for (final want in keys) {
    for (final e in m.entries) {
      if (e.key.toLowerCase() != want.toLowerCase()) continue;
      final v = e.value;
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
  }
  return null;
}

String pickStr(Map<String, dynamic> m, List<String> keys, {String or = '-'}) {
  final v = pick(m, keys);
  if (v == null) return or;
  final s = v.toString().trim();
  return s.isEmpty ? or : s;
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

DateTime? pickTime(Map<String, dynamic> m, List<String> keys) {
  final v = pick(m, keys);
  if (v == null) return null;

  DateTime? dt;
  if (v is DateTime) {
    dt = v;
  } else if (v is num) {
    final n = v.toInt();
    if (n > 1000000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
    } else if (n > 1000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    }
  } else {
    dt = DateTime.tryParse(v.toString());
  }

  if (dt == null) return null;
  // API ส่ง UTC (เช่น ...Z) — แปลงเป็นเวลาเครื่องผู้ใช้ก่อนแสดง
  return dt.isUtc ? dt.toLocal() : dt;
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
