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
  return v is List ? v : const [];
}
