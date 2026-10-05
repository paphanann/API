import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

class OrderLine {
  const OrderLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.price,
    this.imageUrl = '',
  });

  final String sku;
  final String name;
  final int qty;
  final double price;
  final String imageUrl;

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
    this.shippingStatus = '',
    required this.lines,
    this.itemAmount,
    this.discountAmount,
    this.shippingAmount,
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
          imageUrl: pickStr(item, [
            'Image',
            'image',
            'ImageUrl',
            'imageUrl',
            'image_url',
            'ItemImage',
            'itemImage',
            'item_image',
            'ProductImage',
            'productImage',
            'product_image',
            'Thumbnail',
            'thumbnail',
            'Cover',
            'cover',
          ], or: ''),
        ),
      );
    }
    return Order(
      id: pickStr(m, ['MarketplaceOrderId', 'marketplaceOrderId', 'OrderNo', 'orderNo', 'order_sn', 'OrderId', 'order_id', 'Id', 'id'], or: '-'),
      channel: channel,
      customer: _contactName(m),
      phone: _contactPhone(m),
      address: _contactAddress(m),
      createdAt: pickTime(m, ['OrderDate', 'orderDate', 'CreatedAt', 'createdAt', 'CreateTime', 'order_create_time', 'Date']) ?? DateTime.now(),
      status: _orderStatus(pickStr(m, ['OrderStatus', 'orderStatus', 'Status', 'status'], or: '')),
      payment: pickStr(m, ['Payment', 'payment', 'PaymentMethod']),
      shipping: pickStr(m, ['Shipping', 'shipping', 'Logistics', 'Carrier', 'ShippingCarrier', 'shippingCarrier']),
      shippingStatus: _shippingStatus(pickStr(m, [
        'ShippingStatus',
        'shippingStatus',
        'LogisticsStatus',
        'logisticsStatus',
        'ShipStatus',
        'shipStatus',
        'OrderStatus',
        'orderStatus',
        'Status',
        'status',
      ], or: '')),
      lines: lines,
      itemAmount: _optAmount(m, [
        'ItemAmount',
        'itemAmount',
        'item_amount',
        'GoodsAmount',
        'goodsAmount',
        'MerchandiseSubtotal',
        'Subtotal',
        'subtotal',
      ]),
      discountAmount: _optAmount(m, [
        'DiscountAmount',
        'discountAmount',
        'discount_amount',
        'VoucherAmount',
        'voucherAmount',
        'Discount',
        'discount',
      ]),
      shippingAmount: _optAmount(m, [
        'ShippingAmount',
        'shippingAmount',
        'shipping_amount',
        'EstimatedShippingFee',
        'estimated_shipping_fee',
        'ActualShippingFee',
        'actual_shipping_fee',
        'BuyerShippingFee',
        'buyer_paid_shipping_fee',
        'buyer_shipping_fee',
        'ShippingFee',
        'shippingFee',
        'shipping_fee',
        'ShippingCost',
        'LogisticsFee',
        'DeliveryFee',
        'Freight',
        'freight',
        'Postage',
        'postage',
      ]),
      listedTotal: _optAmount(m, [
        'TotalAmount',
        'totalAmount',
        'total_amount',
        'EscrowAmount',
        'BuyerTotalAmount',
        'buyer_total_amount',
        'Total',
        'total',
        'Amount',
      ]),
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
  final String shippingStatus;
  final List<OrderLine> lines;
  final double? itemAmount;
  final double? discountAmount;
  final double? shippingAmount;
  final double? listedTotal;
  final String? sapDocNum;
  final String syncStatus;
  final DateTime? lastSyncedAt;

  double get lineSum {
    var sum = 0.0;
    for (final line in lines) {
      sum += line.amount;
    }
    return sum;
  }

  double get itemsTotal => itemAmount ?? lineSum;
  double get discount => discountAmount ?? 0;
  double get shippingFee {
    final raw = shippingAmount ?? 0;
    if (raw > 0) return raw;
    if (listedTotal != null) {
      final derived = listedTotal! - itemsTotal + discount;
      if (derived > 0.009) return derived;
    }
    return raw;
  }

  double get total {
    if (listedTotal != null) return listedTotal!;
    return itemsTotal - discount + shippingFee;
  }
}

List<Map<String, dynamic>> _contactBags(Map<String, dynamic> m) {
  final bags = <Map<String, dynamic>>[m];
  for (final key in [
    'Recipient',
    'recipient',
    'RecipientAddress',
    'recipientAddress',
    'recipient_address',
    'ShippingAddress',
    'shippingAddress',
    'AddressShipping',
    'address_shipping',
    'Buyer',
    'buyer',
    'CustomerInfo',
    'customerInfo',
    'BillingAddress',
    'billingAddress',
  ]) {
    final v = pick(m, [key]);
    if (v is Map) bags.add(Map<String, dynamic>.from(v));
  }
  return bags;
}

String _firstPlain(List<Map<String, dynamic>> bags, List<String> keys) {
  for (final bag in bags) {
    final s = pickPlainStr(bag, keys, or: '');
    if (s.isNotEmpty) return s;
  }
  return '-';
}

String _addressFrom(Map<String, dynamic> m) {
  final full = pickPlainStr(m, [
    'FullAddress',
    'fullAddress',
    'full_address',
    'CompleteAddress',
    'completeAddress',
    'ShippingFullAddress',
    'shippingFullAddress',
    'AddressText',
    'addressText',
  ], or: '');
  if (full.isNotEmpty) return full;
  final parts = [
    pickPlainStr(m, ['AddressDetail', 'addressDetail', 'address_detail', 'Street', 'street', 'Address', 'address'], or: ''),
    pickPlainStr(m, ['Town', 'town', 'SubDistrict', 'subDistrict', 'sub_district'], or: ''),
    pickPlainStr(m, ['District', 'district', 'City', 'city'], or: ''),
    pickPlainStr(m, ['State', 'state', 'Province', 'province', 'Region', 'region'], or: ''),
    pickPlainStr(m, ['ZipCode', 'zipCode', 'zipcode', 'PostalCode', 'postal_code', 'zip'], or: ''),
  ].where((s) => s.isNotEmpty && s != '-').toList();
  return parts.join(' ');
}

String _contactName(Map<String, dynamic> m) {
  return _firstPlain(_contactBags(m), [
    'RecipientName',
    'recipientName',
    'recipient_name',
    'BuyerName',
    'buyerName',
    'buyer_name',
    'CustomerName',
    'customerName',
    'FullName',
    'fullName',
    'DisplayName',
    'Name',
    'name',
    'CardName',
    'cardName',
    'Customer',
    'customer',
    'buyer_username',
    'BuyerUsername',
    'buyerUsername',
    'Username',
    'username',
  ]);
}

String _contactPhone(Map<String, dynamic> m) {
  return _firstPlain(_contactBags(m), [
    'RecipientPhone',
    'recipientPhone',
    'recipient_phone',
    'BuyerPhone',
    'buyerPhone',
    'buyer_phone',
    'CustomerPhone',
    'customerPhone',
    'PhoneNumber',
    'phoneNumber',
    'Mobile',
    'mobile',
    'Tel',
    'tel',
    'Phone',
    'phone',
  ]);
}

String _contactAddress(Map<String, dynamic> m) {
  for (final bag in _contactBags(m)) {
    final s = _addressFrom(bag);
    if (s.isNotEmpty) return s;
  }
  return _firstPlain(_contactBags(m), [
    'ShippingAddress',
    'shippingAddress',
    'RecipientAddress',
    'recipientAddress',
    'Address',
    'address',
  ]);
}

double? _optAmount(Map<String, dynamic> m, List<String> keys) {
  double? zero;
  for (final bag in _amountBags(m)) {
    for (final key in keys) {
      final v = pick(bag, [key]);
      if (v == null || v is Map || v is List) continue;
      final n = v is num ? v.toDouble() : double.tryParse(v.toString().replaceAll(',', ''));
      if (n == null) continue;
      if (n > 0) return n;
      zero ??= n;
    }
  }
  return zero;
}

List<Map<String, dynamic>> _amountBags(Map<String, dynamic> m) {
  final bags = <Map<String, dynamic>>[m];
  for (final key in [
    'Amounts',
    'amounts',
    'Amount',
    'Breakdown',
    'breakdown',
    'Totals',
    'totals',
    'OrderAmount',
    'orderAmount',
    'Payment',
    'payment',
    'Price',
    'price',
    'Escrow',
    'escrow',
  ]) {
    final v = pick(m, [key]);
    if (v is Map) bags.add(Map<String, dynamic>.from(v));
  }
  return bags;
}

String _shippingStatus(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t == '-') return 'รอจัดส่ง';
  final v = t.toLowerCase();
  if (v.contains('รอจัดส่ง') || v.contains('ready_to_ship') || v.contains('toship') || v.contains('to_ship') || v.contains('processed') || v.contains('unpaid') || v.contains('pending')) {
    return 'รอจัดส่ง';
  }
  if (v.contains('กำลังจัดส่ง') || v.contains('in_transit') || v.contains('shipped') || v.contains('shipping')) {
    return 'กำลังจัดส่ง';
  }
  if (v.contains('ส่งแล้ว') || v.contains('deliver') || v.contains('complete')) {
    return 'ส่งแล้ว';
  }
  if (v.contains('cancel')) return 'ยกเลิก';
  if (RegExp(r'[ก-๙]').hasMatch(t)) return t;
  return 'รอจัดส่ง';
}

OrderStatus _orderStatus(String raw) {
  final v = raw.toLowerCase();
  if (v.contains('cancel')) return OrderStatus.cancelled;
  if (v.contains('success') || v.contains('complete') || v.contains('ship') || v.contains('deliver') || v.contains('paid')) {
    return OrderStatus.success;
  }
  return OrderStatus.pending;
}
