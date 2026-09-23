import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

class OrderLine {
  const OrderLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.price,
  });

  final String sku;
  final String name;
  final int qty;
  final double price;

  double get amount => qty * price;
}

class Order {
  const Order({
    required this.id,
    required this.channel,
    required this.customer,
    required this.phone,
    required this.address,
    required this.createdAt,
    required this.status,
    required this.payment,
    required this.shipping,
    required this.lines,
    this.listedTotal,
    this.sapDocNum,
    this.syncStatus = '',
    this.lastSyncedAt,
  });

  factory Order.fromApi(Map<String, dynamic> m) {
    final channel = ChannelX.fromApi(pickStr(m, ['Platform', 'platform', 'Channel', 'channel'], or: '')) ?? Channel.shopee;
    final lines = <OrderLine>[];
    for (final row in pickList(m, ['Lines', 'lines', 'Items', 'items', 'OrderItems'])) {
      if (row is! Map) continue;
      final item = Map<String, dynamic>.from(row);
      lines.add(
        OrderLine(
          sku: pickStr(item, ['sku', 'Sku', 'item_id', 'ItemId', 'product_id'], or: '-'),
          name: pickStr(item, ['name', 'Name', 'item_name', 'ItemName', 'product_name'], or: '-'),
          qty: pickInt(item, ['qty', 'Qty', 'quantity', 'Quantity'], or: 1),
          price: pickDouble(item, ['price', 'Price', 'unit_price', 'UnitPrice']),
        ),
      );
    }
    return Order(
      id: pickStr(m, ['MarketplaceOrderId', 'marketplaceOrderId', 'OrderNo', 'orderNo', 'order_sn', 'OrderId', 'order_id', 'Id', 'id'], or: '-'),
      channel: channel,
      customer: pickStr(m, ['Customer', 'customer', 'CustomerName', 'CardName', 'cardName', 'buyer_username', 'Buyer', 'buyer'], or: '-'),
      phone: pickStr(m, ['Phone', 'phone', 'CustomerPhone']),
      address: pickStr(m, ['Address', 'address', 'ShippingAddress']),
      createdAt: pickTime(m, ['OrderDate', 'orderDate', 'CreatedAt', 'createdAt', 'CreateTime', 'order_create_time', 'Date']) ?? DateTime.now(),
      status: _orderStatus(pickStr(m, ['OrderStatus', 'orderStatus', 'Status', 'status'], or: '')),
      payment: pickStr(m, ['Payment', 'payment', 'PaymentMethod']),
      shipping: pickStr(m, ['Shipping', 'shipping', 'Logistics', 'Carrier']),
      lines: lines,
      listedTotal: pick(m, ['TotalAmount', 'totalAmount', 'Total', 'total', 'total_amount', 'Amount']) == null
          ? null
          : pickDouble(m, ['TotalAmount', 'totalAmount', 'Total', 'total', 'total_amount', 'Amount']),
      sapDocNum: () {
        final v = pickStr(m, ['SapDocNum', 'sapDocNum', 'DocNum', 'docNum'], or: '');
        return v.isEmpty ? null : v;
      }(),
      syncStatus: pickStr(m, ['SyncStatus', 'syncStatus'], or: ''),
      lastSyncedAt: pickTime(m, ['LastSyncedAt', 'lastSyncedAt', 'SyncedAt', 'syncedAt']),
    );
  }

  final String id;
  final Channel channel;
  final String customer;
  final String phone;
  final String address;
  final DateTime createdAt;
  final OrderStatus status;
  final String payment;
  final String shipping;
  final List<OrderLine> lines;
  final double? listedTotal;
  final String? sapDocNum;
  final String syncStatus;
  final DateTime? lastSyncedAt;

  double get total {
    if (listedTotal != null) return listedTotal!;
    var sum = 0.0;
    for (final line in lines) {
      sum += line.amount;
    }
    return sum;
  }
}

OrderStatus _orderStatus(String raw) {
  final v = raw.toLowerCase();
  if (v.contains('cancel')) return OrderStatus.cancelled;
  if (v.contains('success') || v.contains('complete') || v.contains('ship') || v.contains('deliver') || v.contains('paid')) {
    return OrderStatus.success;
  }
  return OrderStatus.pending;
}
