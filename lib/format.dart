import 'package:intl/intl.dart';

final baht = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);
final nFmt = NumberFormat('#,##0');
final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
final dtSec = DateFormat('dd/MM/yyyy HH:mm:ss');

/// แสดงวันที่เวลาเป็นเวลาเครื่องผู้ใช้ (แก้เคส API ส่ง UTC)
String formatDt(DateTime? value, {bool withSeconds = false}) {
  if (value == null) return '-';
  final local = value.isUtc ? value.toLocal() : value.toLocal();
  return (withSeconds ? dtSec : dtFmt).format(local);
}
