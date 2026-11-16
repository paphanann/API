import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/models.dart';

Widget pill(String text, Color fg, Color bg, {double size = 12}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(color: fg, fontSize: size, fontWeight: FontWeight.w600),
    ),
  );
}

Widget orderPill(OrderStatus s) {
  switch (s) {
    case OrderStatus.unpaid:
      return pill('รอชำระเงิน', const Color(0xFF1D4ED8), Pal.infoBg);
    case OrderStatus.pending:
      return pill('รอดำเนินการ', const Color(0xFFB45309), Pal.warnBg);
    case OrderStatus.shipping:
      return pill('กำลังจัดส่ง', const Color(0xFF0369A1), const Color(0xFFE0F2FE));
    case OrderStatus.success:
      return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
    case OrderStatus.cancelled:
      return pill('ยกเลิก', const Color(0xFFB91C1C), Pal.errBg);
    case OrderStatus.returned:
      return pill('คืนสินค้า/คืนเงิน', const Color(0xFF7C3AED), const Color(0xFFEDE9FE));
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
  if (v == 'so_fail') return pill('ใบ SO ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (v == 'so_ok') return pill('สร้างใบ SO สำเร็จ', const Color(0xFF15803D), Pal.okBg);
  if (v == 'delivery_fail') return pill('Delivery ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (v == 'delivery_wait') return pill('รอสร้าง Delivery', const Color(0xFFB45309), Pal.warnBg);
  if (v == 'delivery_ok') return pill('สร้าง Delivery สำเร็จ', const Color(0xFF15803D), Pal.okBg);
  if (v == 'invoice_fail') return pill('A/R Invoice ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (v == 'invoice_wait') return pill('รอสร้าง A/R Invoice', const Color(0xFFB45309), Pal.warnBg);
  if (v == 'invoice_ok') return pill('สร้าง A/R Invoice สำเร็จ', const Color(0xFF15803D), Pal.okBg);
  if (v == 'cancelled' || v.contains('cancel')) return pill('ยกเลิก', const Color(0xFFB91C1C), Pal.errBg);
  if (v == 'ok' || v.contains('sap_ok') || v.contains('sapok')) {
    return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
  }
  if (v.contains('invoice_error')) return pill('Invoice ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (v.contains('delivery_error')) return pill('Delivery ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (v.contains('sap_error') || v.contains('error')) {
    return pill('ใบ SO ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  }
  if (v.contains('sending') || v.contains('saved') || v.isEmpty || v == 'wait') {
    return pill('รอสร้างใบ SO', const Color(0xFFB45309), Pal.warnBg);
  }
  return pill(raw!, Pal.muted, const Color(0xFFF3F4F6));
}

Widget invoicePill(String? doc, String? status) {
  final docNo = (doc ?? '').trim();
  final state = (status ?? '').trim().toLowerCase();
  if (state == 'error') return pill('Invoice ล้มเหลว', const Color(0xFFB91C1C), Pal.errBg);
  if (docNo.isNotEmpty) return pill(docNo, const Color(0xFF15803D), Pal.okBg);
  return const Text('-', style: TextStyle(color: Pal.muted));
}

Widget settlementPill(String? status) {
  if ((status ?? '').trim().toLowerCase() == 'waiting_marketplace') {
    return pill('รอรับเงิน', const Color(0xFFB45309), Pal.warnBg);
  }
  return const Text('-', style: TextStyle(color: Pal.muted));
}

Widget dashSoPill({double size = 12}) => pill('สร้าง SO', const Color(0xFF2563EB), Pal.infoBg, size: size);
Widget dashDeliveryPill({double size = 12}) => pill('สร้าง Delivery', const Color(0xFF7C3AED), const Color(0xFFEDE9FE), size: size);
Widget waitSoPill({double size = 12}) => pill('รอสร้าง SO', const Color(0xFFC2410C), const Color(0xFFFFEDD5), size: size);
Widget waitTrPill({double size = 12}) => pill('รอสร้าง TR', const Color(0xFFC2410C), const Color(0xFFFFEDD5), size: size);
Widget soCreatedPill({double size = 12}) => pill('สร้าง SO แล้ว', const Color(0xFF15803D), Pal.okBg, size: size);

Widget soReadyPill({double size = 12}) => pill('พร้อมสร้าง', const Color(0xFFB45309), Pal.warnBg, size: size);
Widget soSentPill({double size = 12}) => pill('ส่ง SAP', const Color(0xFFC2410C), const Color(0xFFFFEDD5), size: size);
Widget soDonePill({double size = 12}) => pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg, size: size);
Widget soFailPill({double size = 12}) => pill('ผิดพลาด', const Color(0xFFB91C1C), Pal.errBg, size: size);

Widget sapStatusPill(String raw, {double size = 12}) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == '-') return const Text('-');
  if (v.contains('success') || v.contains('สำเร็จ')) {
    return pill('Success', const Color(0xFF15803D), Pal.okBg, size: size);
  }
  if (v.contains('fail') || v.contains('error') || v.contains('ล้มเหลว')) {
    return pill('Failed', const Color(0xFFB91C1C), Pal.errBg, size: size);
  }
  if (v.contains('pending') || v.contains('wait') || v.contains('รอ')) {
    return pill('Pending SAP', const Color(0xFFC2410C), const Color(0xFFFFEDD5), size: size);
  }
  return pill(raw, Pal.muted, const Color(0xFFF3F4F6), size: size);
}

Widget transferPill(String raw) {
  final v = raw.trim();
  if (v.isEmpty || v == '-') return pill('รอดำเนินการ', const Color(0xFFB45309), Pal.warnBg);
  final lower = v.toLowerCase();
  if (lower.contains('success') || lower.contains('done') || lower.contains('complete') || lower.contains('สำเร็จ')) {
    return pill('สำเร็จ', const Color(0xFF15803D), Pal.okBg);
  }
  if (lower.contains('cancel') || lower.contains('fail') || lower.contains('error') || lower.contains('ยกเลิก')) {
    return pill('ยกเลิก', const Color(0xFFB91C1C), Pal.errBg);
  }
  if (lower.contains('draft') || lower.contains('ฉบับร่าง')) {
    return pill('ฉบับร่าง', Pal.muted, const Color(0xFFF3F4F6));
  }
  if (lower.contains('pending') || lower.contains('wait') || lower.contains('รอ')) {
    return pill('รอดำเนินการ', const Color(0xFFB45309), Pal.warnBg);
  }
  return pill(v, Pal.muted, const Color(0xFFF3F4F6));
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

Widget productPill(ProductStatus s, {int? stock}) {
  if (s == ProductStatus.inactive) {
    return pill('ปิดการขาย', const Color(0xFFB91C1C), Pal.errBg);
  }
  if (stock != null && stock <= 0) {
    return pill('สินค้าหมด', const Color(0xFFB45309), Pal.warnBg);
  }
  return pill('พร้อมขาย', const Color(0xFF15803D), Pal.okBg);
}

Widget productProblemCell(String text) {
  if (text.isEmpty || text == '-') {
    return const Text('-', style: TextStyle(color: Pal.muted, fontSize: 13));
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Pal.text),
        ),
      ),
    ],
  );
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
