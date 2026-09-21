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
      status: statusRaw.contains('error') || statusRaw.contains('fail')
          ? SyncStatus.error
          : statusRaw.contains('pending') || statusRaw.contains('wait')
              ? SyncStatus.pending
              : SyncStatus.success,
      msg: friendlyPublicSummary(
        platform: channel.label,
        payload: payload,
        orderNo: orderNo,
        fallback: rawMsg is String ? rawMsg : (rawMsg == null ? '-' : rawMsg.toString()),
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
}
