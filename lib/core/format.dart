import 'package:intl/intl.dart';

final baht = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);
final nFmt = NumberFormat('#,##0');
final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
final dtSec = DateFormat('dd/MM/yyyy HH:mm:ss');
final dayFmt = DateFormat('dd/MM/yyyy');
final timeFmt = DateFormat('HH:mm');

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

bool inDayRange(DateTime? value, DateTime? from, DateTime? to) {
  if (from == null || to == null) return true;
  if (value == null) return true;
  final day = dateOnly(value);
  return !day.isBefore(from) && !day.isAfter(to);
}

/// แสดงวันที่เวลา — ค่าจาก pickTime เป็นเวลาเครื่องแล้ว ไม่ต้อง toLocal ซ้ำ
String formatDt(DateTime? value, {bool withSeconds = false}) {
  if (value == null) return '-';
  return (withSeconds ? dtSec : dtFmt).format(value);
}
