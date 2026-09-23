import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

class SyncRow {
  const SyncRow({
    required this.time,
    required this.channel,
    required this.orderNo,
    required this.action,
    required this.status,
    required this.msg,
    this.docEntry,
    this.docNum,
    this.id = '',
    this.orderCount = 0,
    this.productCount = 0,
  });

  factory SyncRow.fromApi(Map<String, dynamic> m) {
    final statusRaw = pickStr(m, ['Status', 'status', 'SyncStatus'], or: '').toLowerCase();
    final channel = ChannelX.fromApi(pickStr(m, ['Platform', 'platform', 'Channel', 'channel'], or: '')) ?? Channel.shopee;
    var orderNo = pickStr(m, ['MarketplaceOrderId', 'marketplaceOrderId', 'OrderNo', 'orderNo', 'OrderId', 'order_id', 'order_sn'], or: '-');
    final rawMsg = pick(m, ['Message', 'message', 'Msg', 'msg', 'Payload', 'payload', 'Detail', 'detail']);
    final payload = tryJsonMap(rawMsg) ?? tryJsonMap(pick(m, ['Data', 'data', 'Body', 'body']));
    if (payload != null && (orderNo.isEmpty || orderNo == '-')) {
      final fromPayload = pickStr(payload, ['order_sn', 'orderSn', 'OrderNo', 'order_id', 'MarketplaceOrderId'], or: '');
      if (fromPayload.isNotEmpty && fromPayload != '-') orderNo = fromPayload;
    }
    return SyncRow(
      id: pickStr(m, ['Id', 'id', 'LogId'], or: ''),
      time: pickTime(m, ['Time', 'time', 'CreatedAt', 'createdAt', 'SyncedAt', 'syncedAt']) ?? DateTime.now(),
      channel: channel,
      orderNo: orderNo,
      action: pickStr(m, ['Action', 'action', 'Type', 'type'], or: '-'),
      status: () {
        if (statusRaw.contains('partial') || statusRaw.contains('บางส่วน')) {
          return SyncStatus.partial;
        }
        if (statusRaw.contains('error') || statusRaw.contains('fail')) {
          return SyncStatus.error;
        }
        if (statusRaw.contains('running') || statusRaw.contains('pending') || statusRaw.contains('wait')) {
          return SyncStatus.running;
        }
        // skipped / noop / unchanged → สำเร็จ (รายละเอียดอยู่ในข้อความ)
        return SyncStatus.success;
      }(),
      msg: friendlySyncMessage(
        friendlyPublicSummary(
          platform: channel.label,
          payload: payload,
          orderNo: orderNo,
          fallback: rawMsg is String ? rawMsg : (rawMsg == null ? '-' : rawMsg.toString()),
        ),
      ),
      docEntry: () {
        final v = pickStr(m, ['SapDocEntry', 'sapDocEntry', 'DocEntry', 'docEntry'], or: '');
        return v.isEmpty ? null : v;
      }(),
      docNum: () {
        final v = pickStr(m, ['SapDocNum', 'sapDocNum', 'DocNum', 'docNum'], or: '');
        return v.isEmpty ? null : v;
      }(),
      orderCount: pickInt(m, ['OrderCount', 'orderCount']),
      productCount: pickInt(m, ['ProductCount', 'productCount']),
    );
  }

  final DateTime time;
  final Channel channel;
  final String orderNo;
  final String action;
  final SyncStatus status;
  final String msg;
  final String? docEntry;
  final String? docNum;
  final String id;
  final int orderCount;
  final int productCount;

  String get routeId {
    if (id.isNotEmpty && id != '-') return id;
    return Uri.encodeComponent('$orderNo|${time.toIso8601String()}');
  }

  /// ป้ายประเภทเหตุการณ์ (ไม่ใช่จำนวนออเดอร์)
  String get actionLabel {
    final a = action.trim().toLowerCase();
    if (a == 'order') return 'Order Sync';
    if (a == 'incremental') return 'Incremental Sync';
    if (a == 'full' || a == 'run') return 'Full Sync';
    if (a.isEmpty || a == '-') return 'Sync Event';
    return action;
  }

  /// ข้อความสั้นบน Dashboard — ไม่โชว์ JSON / IP ยาว
  String get dashDetail {
    final short = friendlySyncMessage(msg);
    if (short != '-' && short.isNotEmpty) return short;
    if (status == SyncStatus.error) return 'เชื่อมต่อ API ไม่สำเร็จ';
    if (status == SyncStatus.running) return 'กำลังซิงก์';
    if (status == SyncStatus.partial) return 'สำเร็จบางส่วน';
    if (productCount > 0) return 'อัปเดตสินค้า $productCount รายการ';
    return 'ไม่พบการเปลี่ยนแปลง';
  }
}

String friendlySyncMessage(String raw) {
  final text = raw.replaceAll('\n', ' ').trim();
  if (text.isEmpty || text == '-') return '-';
  final lower = text.toLowerCase();
  if (lower.contains('whitelist') ||
      lower.contains('undeclared') ||
      (lower.contains('ip') && (lower.contains('request') || lower.contains('source')))) {
    return 'IP ไม่อยู่ใน Whitelist';
  }
  if (lower.contains('frequency exceeds') || lower.contains('rate limit')) {
    return 'เรียก API บ่อยเกินไป (Rate limit)';
  }
  if (lower.contains('expire') || lower.contains('หมดอายุ') || lower.contains('unauthorized') || lower.contains('reauth')) {
    return 'หมดอายุ';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'เชื่อมต่อ API ไม่สำเร็จ';
  }
  return text
      .replaceFirst(RegExp(r'^(Incremental|Full) Sync:\s*', caseSensitive: false), '')
      .trim();
}
