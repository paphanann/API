import 'package:intl/intl.dart';

final baht = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);
final nFmt = NumberFormat('#,##0');
final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
