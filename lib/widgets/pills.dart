import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/models.dart';

Widget pill(String text, Color fg, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

Widget orderPill(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return pill('รอดำเนินการ', const Color(0xFFB45309), Pal.warnBg);
    case OrderStatus.success:
      return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
    case OrderStatus.cancelled:
      return pill('ยกเลิก', const Color(0xFFB91C1C), Pal.errBg);
  }
}

Widget syncPill(SyncStatus s) {
  switch (s) {
    case SyncStatus.running:
      return pill('กำลังซิงก์', const Color(0xFF1D4ED8), const Color(0xFFDBEAFE));
    case SyncStatus.success:
      return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
    case SyncStatus.partial:
      return pill('สำเร็จบางส่วน', const Color(0xFFC2410C), const Color(0xFFFFEDD5));
    case SyncStatus.error:
      return pill('ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  }
}

Widget orderSyncPill(String? raw) {
  final v = (raw ?? '').toLowerCase();
  if (v.contains('sap_ok') || v.contains('sapok') || v == 'ok') {
    return pill('เข้า SAP แล้ว', const Color(0xFF15803D), Pal.okBg);
  }
  if (v.contains('sap_error') || v.contains('error')) {
    return pill('SAP ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  }
  if (v.contains('saved') || v.isEmpty) {
    return pill('รอ SAP', const Color(0xFFB45309), Pal.warnBg);
  }
  return pill(raw!, Pal.muted, const Color(0xFFF3F4F6));
}

Widget warehouseStatusPill(String raw) {
  final v = raw.trim();
  if (v.isEmpty || v == '-') return const Text('-');
  final lower = v.toLowerCase();
  if (lower.contains('inactive') || lower.contains('disable') || lower.contains('off') || lower.contains('ไม่ใช้งาน')) {
    return pill('ไม่ใช้งาน', Pal.muted, const Color(0xFFF3F4F6));
  }
  if (lower.contains('pending') || lower.contains('wait') || lower.contains('รอ')) {
    return pill('รอดำเนินการ', const Color(0xFFB45309), Pal.warnBg);
  }
  if (lower.contains('active') || lower.contains('enable') || lower.contains('online') || lower.contains('ใช้งาน')) {
    return pill('ใช้งาน', const Color(0xFF15803D), Pal.okBg);
  }
  return pill(v, Pal.muted, const Color(0xFFF3F4F6));
}

Widget productPill(ProductStatus s) {
  switch (s) {
    case ProductStatus.active:
      return pill('พร้อมขาย', const Color(0xFF15803D), Pal.okBg);
    case ProductStatus.inactive:
      return pill('ปิดขาย', const Color(0xFFB91C1C), Pal.errBg);
    case ProductStatus.draft:
      return pill('ฉบับร่าง', Pal.muted, const Color(0xFFF3F4F6));
  }
}

Widget connPill(ConnStatus s) {
  switch (s) {
    case ConnStatus.waiting:
      return pill('รอการเชื่อมต่อ', const Color(0xFFB45309), Pal.warnBg);
    case ConnStatus.sandbox:
      return pill('เชื่อมต่อแล้ว (Sandbox)', const Color(0xFF15803D), Pal.okBg);
    case ConnStatus.live:
      return pill('เชื่อมต่อแล้ว', const Color(0xFF15803D), Pal.okBg);
    case ConnStatus.off:
      return pill('ยังไม่เชื่อมต่อ', Pal.muted, const Color(0xFFF3F4F6));
  }
}
