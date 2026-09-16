import 'package:flutter/material.dart';

import 'json_util.dart';
import 'theme.dart';

enum Channel { shopee, tiktok, lazada }

extension ChannelX on Channel {
  String get label {
    switch (this) {
      case Channel.shopee:
        return 'Shopee';
      case Channel.tiktok:
        return 'TikTok Shop';
      case Channel.lazada:
        return 'Lazada';
    }
  }

  String get shortLabel {
    switch (this) {
      case Channel.shopee:
        return 'Shopee';
      case Channel.tiktok:
        return 'TikTok';
      case Channel.lazada:
        return 'Lazada';
    }
  }

  Color get color {
    switch (this) {
      case Channel.shopee:
        return Pal.shopee;
      case Channel.tiktok:
        return Pal.tiktok;
      case Channel.lazada:
        return Pal.lazada;
    }
  }

  String get mark {
    switch (this) {
      case Channel.shopee:
        return 'S';
      case Channel.tiktok:
        return '♪';
      case Channel.lazada:
        return 'L';
    }
  }

  /// path ของ Backend เช่น /api/connections/shopee/connect
  String get apiSlug {
    switch (this) {
      case Channel.shopee:
        return 'shopee';
      case Channel.tiktok:
        return 'tiktok';
      case Channel.lazada:
        return 'lazada';
    }
  }

  /// query ของ GET /api/orders?platform=
  String get apiPlatform {
    switch (this) {
      case Channel.shopee:
        return 'Shopee';
      case Channel.tiktok:
        return 'TikTok';
      case Channel.lazada:
        return 'Lazada';
    }
  }

  static Channel? fromApi(String? raw) {
    final v = (raw ?? '').toLowerCase().replaceAll(' ', '');
    if (v.contains('shopee')) return Channel.shopee;
    if (v.contains('tiktok')) return Channel.tiktok;
    if (v.contains('lazada')) return Channel.lazada;
    return null;
  }
}

enum OrderStatus { pending, success, cancelled }

enum ProductStatus { active, inactive, draft }

enum SyncStatus { success, error, pending }

enum ConnStatus { waiting, sandbox, live, off }

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
      customer: pickStr(m, ['Customer', 'customer', 'CustomerName', 'buyer_username', 'Buyer'], or: '-'),
      phone: pickStr(m, ['Phone', 'phone', 'CustomerPhone']),
      address: pickStr(m, ['Address', 'address', 'ShippingAddress']),
      createdAt: pickTime(m, ['CreatedAt', 'createdAt', 'CreateTime', 'order_create_time', 'Date']) ?? DateTime.now(),
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

class Product {
  const Product({
    required this.sku,
    required this.name,
    required this.channel,
    required this.price,
    required this.stock,
    required this.status,
    required this.synced,
  });

  factory Product.fromApi(Map<String, dynamic> m) {
    final st = pickStr(m, ['Status', 'status', 'ProductStatus'], or: '').toLowerCase();
    return Product(
      sku: pickStr(m, ['Sku', 'sku', 'MarketplaceSku', 'ItemId', 'item_id'], or: '-'),
      name: pickStr(m, ['Name', 'name', 'ProductName', 'item_name'], or: '-'),
      channel: ChannelX.fromApi(pickStr(m, ['Platform', 'platform'], or: '')) ?? Channel.shopee,
      price: pickDouble(m, ['Price', 'price', 'Amount']),
      stock: pickInt(m, ['Stock', 'stock', 'Quantity']),
      status: st.contains('inactive') || st.contains('off')
          ? ProductStatus.inactive
          : st.contains('draft')
              ? ProductStatus.draft
              : ProductStatus.active,
      synced: pickStr(m, ['Synced', 'synced', 'SyncStatus'], or: '').toLowerCase().contains('sync') ||
          pick(m, ['Synced', 'synced']) == true,
    );
  }

  final String sku;
  final String name;
  final Channel channel;
  final double price;
  final int stock;
  final ProductStatus status;
  final bool synced;
}

class DashData {
  const DashData({
    required this.totalOrders,
    required this.pendingOrders,
    required this.successOrders,
    required this.connected,
    required this.weekLabels,
    required this.shopeeWeek,
    required this.tiktokWeek,
    required this.lazadaWeek,
    required this.shopeeShare,
    required this.tiktokShare,
    required this.lazadaShare,
  });

  factory DashData.empty() => const DashData(
        totalOrders: 0,
        pendingOrders: 0,
        successOrders: 0,
        connected: 0,
        weekLabels: [],
        shopeeWeek: [],
        tiktokWeek: [],
        lazadaWeek: [],
        shopeeShare: 0,
        tiktokShare: 0,
        lazadaShare: 0,
      );

  factory DashData.fromApi(Map<String, dynamic> m) {
    List<double> nums(List<String> keys) {
      final v = pick(m, keys);
      if (v is! List) return const [];
      return [
        for (final x in v) x is num ? x.toDouble() : double.tryParse('$x') ?? 0,
      ];
    }

    List<String> labels() {
      final v = pick(m, ['weekLabels', 'WeekLabels', 'labels', 'Labels']);
      if (v is! List) return const [];
      return [for (final x in v) '$x'];
    }

    return DashData(
      totalOrders: pickInt(m, ['totalOrders', 'TotalOrders', 'OrderCount', 'orderCount']),
      pendingOrders: pickInt(m, ['pendingOrders', 'PendingOrders', 'Pending']),
      successOrders: pickInt(m, ['successOrders', 'SuccessOrders', 'Success']),
      connected: pickInt(m, ['connected', 'Connected', 'ConnectedShops', 'connectedShops']),
      weekLabels: labels(),
      shopeeWeek: nums(['shopeeWeek', 'ShopeeWeek']),
      tiktokWeek: nums(['tiktokWeek', 'TiktokWeek', 'TikTokWeek']),
      lazadaWeek: nums(['lazadaWeek', 'LazadaWeek']),
      shopeeShare: pickDouble(m, ['shopeeShare', 'ShopeeShare']),
      tiktokShare: pickDouble(m, ['tiktokShare', 'TiktokShare', 'TikTokShare']),
      lazadaShare: pickDouble(m, ['lazadaShare', 'LazadaShare']),
    );
  }

  factory DashData.fromLive({required List<Order> orders, required List<ShopConn> shops}) {
    final today = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
    ];
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    List<double> week(Channel c) => [
          for (final day in days) orders.where((o) => o.channel == c && sameDay(o.createdAt, day)).length.toDouble(),
        ];
    final total = orders.length;
    double share(Channel c) => total == 0 ? 0 : orders.where((o) => o.channel == c).length * 100 / total;
    return DashData(
      totalOrders: orders.length,
      pendingOrders: orders.where((o) => o.status == OrderStatus.pending).length,
      successOrders: orders.where((o) => o.status == OrderStatus.success).length,
      connected: shops.where((s) => s.connected).length,
      weekLabels: [for (final d in days) '${d.day}/${d.month}'],
      shopeeWeek: week(Channel.shopee),
      tiktokWeek: week(Channel.tiktok),
      lazadaWeek: week(Channel.lazada),
      shopeeShare: share(Channel.shopee),
      tiktokShare: share(Channel.tiktok),
      lazadaShare: share(Channel.lazada),
    );
  }

  final int totalOrders;
  final int pendingOrders;
  final int successOrders;
  final int connected;
  final List<String> weekLabels;
  final List<double> shopeeWeek;
  final List<double> tiktokWeek;
  final List<double> lazadaWeek;
  final double shopeeShare;
  final double tiktokShare;
  final double lazadaShare;

  bool get hasStats => totalOrders > 0 || pendingOrders > 0 || successOrders > 0 || connected > 0;
  bool get hasCharts => shopeeWeek.isNotEmpty || tiktokWeek.isNotEmpty || lazadaWeek.isNotEmpty;

  DashData merge(DashData live) {
    return DashData(
      totalOrders: hasStats ? totalOrders : live.totalOrders,
      pendingOrders: hasStats ? pendingOrders : live.pendingOrders,
      successOrders: hasStats ? successOrders : live.successOrders,
      connected: hasStats ? connected : live.connected,
      weekLabels: weekLabels.isNotEmpty ? weekLabels : live.weekLabels,
      shopeeWeek: shopeeWeek.isNotEmpty ? shopeeWeek : live.shopeeWeek,
      tiktokWeek: tiktokWeek.isNotEmpty ? tiktokWeek : live.tiktokWeek,
      lazadaWeek: lazadaWeek.isNotEmpty ? lazadaWeek : live.lazadaWeek,
      shopeeShare: shopeeShare > 0 ? shopeeShare : live.shopeeShare,
      tiktokShare: tiktokShare > 0 ? tiktokShare : live.tiktokShare,
      lazadaShare: lazadaShare > 0 ? lazadaShare : live.lazadaShare,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.companyName,
    required this.taxId,
    required this.address,
    required this.erp,
    required this.endpoint,
    required this.autoSync,
    required this.notifyError,
    required this.notifySuccess,
  });

  factory AppSettings.blank() => const AppSettings(
        companyName: '',
        taxId: '',
        address: '',
        erp: 'SAP S/4HANA',
        endpoint: '',
        autoSync: true,
        notifyError: true,
        notifySuccess: false,
      );

  factory AppSettings.fromApi(Map<String, dynamic> m) {
    return AppSettings(
      companyName: pickStr(m, ['companyName', 'CompanyName', 'Name'], or: ''),
      taxId: pickStr(m, ['taxId', 'TaxId'], or: ''),
      address: pickStr(m, ['address', 'Address'], or: ''),
      erp: pickStr(m, ['erp', 'Erp'], or: 'SAP S/4HANA'),
      endpoint: pickStr(m, ['endpoint', 'Endpoint'], or: ''),
      autoSync: pick(m, ['autoSync', 'AutoSync']) == true,
      notifyError: pick(m, ['notifyError', 'NotifyError']) != false,
      notifySuccess: pick(m, ['notifySuccess', 'NotifySuccess']) == true,
    );
  }

  final String companyName;
  final String taxId;
  final String address;
  final String erp;
  final String endpoint;
  final bool autoSync;
  final bool notifyError;
  final bool notifySuccess;

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'taxId': taxId,
        'address': address,
        'erp': erp,
        'endpoint': endpoint,
        'autoSync': autoSync,
        'notifyError': notifyError,
        'notifySuccess': notifySuccess,
      };
}

class StockRow {
  const StockRow({
    required this.sku,
    required this.name,
    required this.wh,
    required this.available,
    required this.reserved,
    required this.shopee,
    required this.tiktok,
    required this.lazada,
    required this.updatedAt,
  });

  factory StockRow.fromApi(Map<String, dynamic> m) {
    return StockRow(
      sku: pickStr(m, ['Sku', 'sku', 'ItemCode', 'itemCode', 'item_code']),
      name: pickStr(m, ['Name', 'name', 'ProductName', 'ItemName', 'itemName']),
      wh: pickStr(m, ['Warehouse', 'warehouse', 'Wh', 'wh', 'WhsCode', 'whsCode', 'WarehouseCode']),
      available: pickInt(m, ['Available', 'available', 'OnHand', 'onHand', 'Quantity', 'Stock', 'Qty']),
      reserved: pickInt(m, ['Reserved', 'reserved', 'Committed', 'committed']),
      shopee: pickBool(m, ['Shopee', 'shopee', 'OnShopee']) == true,
      tiktok: pickBool(m, ['TikTok', 'Tiktok', 'tiktok', 'OnTikTok']) == true,
      lazada: pickBool(m, ['Lazada', 'lazada', 'OnLazada']) == true,
      updatedAt: pickTime(m, ['UpdatedAt', 'updatedAt', 'LastUpdated', 'lastUpdated', 'UpdateDate']) ?? DateTime.now(),
    );
  }

  final String sku;
  final String name;
  final String wh;
  final int available;
  final int reserved;
  final bool shopee;
  final bool tiktok;
  final bool lazada;
  final DateTime updatedAt;
}

class ShopConn {
  const ShopConn({
    required this.channel,
    required this.status,
    required this.shop,
    required this.shopId,
    required this.lastConnected,
    required this.lastSync,
    required this.health,
    this.needsReauth = false,
  });

  factory ShopConn.empty(Channel channel) {
    return ShopConn(
      channel: channel,
      status: ConnStatus.waiting,
      shop: '-',
      shopId: '-',
      lastConnected: null,
      lastSync: null,
      health: '-',
    );
  }

  factory ShopConn.fromApi(Map<String, dynamic> m) {
    final channel = ChannelX.fromApi(pickStr(m, ['Platform', 'platform'], or: '')) ?? Channel.shopee;
    final statusRaw = pickStr(m, ['Status', 'status'], or: '').toLowerCase().replaceAll(' ', '_');
    // Access token พอสำหรับขึ้นเขียว — ไม่บังคับ HasRefreshToken (หลังบ้านอาจไม่ส่งมา)
    final hasToken = pickBool(m, ['HasToken', 'hasToken', 'HasAccessToken', 'hasAccessToken']);
    final expired = pickBool(m, [
          'TokenExpired',
          'tokenExpired',
          'RefreshExpired',
          'refreshExpired',
          'RefreshTokenExpired',
          'refreshTokenExpired',
        ]) ==
        true;
    final askedReauth = pickBool(m, ['NeedsReauth', 'needsReauth', 'NeedReauthorize', 'needReauthorize']) == true;
    const dead = {
      'expired',
      'disconnected',
      'invalid',
      'no_token',
      'notoken',
      'unauthorized',
      'reauth',
      'token_expired',
      'revoked',
    };
    final tokenMissing = hasToken == false || expired || askedReauth || dead.contains(statusRaw);
    final looksLive = statusRaw == 'connected' || statusRaw == 'live' || statusRaw == 'success';
    final connected = looksLive && !tokenMissing;
    final shop = pickStr(m, ['ShopName', 'shopName', 'shop_name', 'Name', 'Account', 'account']);
    // Lazada: แสดง Seller ID แยกจากอีเมลล็อกอิน — ถ้ามี SellerId ให้ใช้ก่อน
    final shopId = pickStr(m, channel == Channel.lazada
        ? ['SellerId', 'sellerId', 'seller_id', 'ShopId', 'shopId', 'shop_id']
        : [
            'ShopId',
            'shopId',
            'shop_id',
            'SellerId',
            'sellerId',
            'seller_id',
            'OpenId',
            'openId',
          ]);
    final hadShop = (shop.isNotEmpty && shop != '-') || (shopId.isNotEmpty && shopId != '-');
    return ShopConn(
      channel: channel,
      status: connected
          ? ConnStatus.live
          : (tokenMissing && (looksLive || hadShop) ? ConnStatus.waiting : ConnStatus.off),
      shop: shop,
      shopId: shopId,
      lastConnected: pickTime(m, [
        'ConnectedAt',
        'connectedAt',
        'connected_at',
        'AuthorizedAt',
        'authorizedAt',
        'authorized_at',
      ]),
      lastSync: pickTime(m, ['LastSyncAt', 'lastSyncAt', 'last_sync_at']),
      health: connected ? 'ปกติ' : '-',
      needsReauth: tokenMissing && (looksLive || hadShop || statusRaw == 'expired'),
    );
  }

  final Channel channel;
  final ConnStatus status;
  final String shop;
  final String shopId;
  final DateTime? lastConnected;
  final DateTime? lastSync;
  final String health;
  final bool needsReauth;

  String get idLabel => channel == Channel.lazada ? 'Seller ID' : 'Shop ID';

  bool get connected => status == ConnStatus.live || status == ConnStatus.sandbox;
}

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
  });

  factory SyncRow.fromApi(Map<String, dynamic> m) {
    final statusRaw = pickStr(m, ['Status', 'status', 'SyncStatus'], or: '').toLowerCase();
    return SyncRow(
      id: pickStr(m, ['Id', 'id', 'LogId'], or: ''),
      time: pickTime(m, ['Time', 'time', 'CreatedAt', 'createdAt', 'SyncedAt', 'syncedAt']) ?? DateTime.now(),
      channel: ChannelX.fromApi(pickStr(m, ['Platform', 'platform', 'Channel', 'channel'], or: '')) ?? Channel.shopee,
      orderNo: pickStr(m, ['MarketplaceOrderId', 'marketplaceOrderId', 'OrderNo', 'orderNo', 'OrderId', 'order_id'], or: '-'),
      action: pickStr(m, ['Action', 'action', 'Type', 'type'], or: '-'),
      status: statusRaw.contains('error') || statusRaw.contains('fail')
          ? SyncStatus.error
          : statusRaw.contains('pending') || statusRaw.contains('wait')
              ? SyncStatus.pending
              : SyncStatus.success,
      msg: pickStr(m, ['Message', 'message', 'Msg', 'msg'], or: '-'),
      docEntry: () {
        final v = pickStr(m, ['SapDocEntry', 'sapDocEntry', 'DocEntry', 'docEntry'], or: '');
        return v.isEmpty ? null : v;
      }(),
      docNum: () {
        final v = pickStr(m, ['SapDocNum', 'sapDocNum', 'DocNum', 'docNum'], or: '');
        return v.isEmpty ? null : v;
      }(),
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

  String get routeId {
    if (id.isNotEmpty && id != '-') return id;
    return Uri.encodeComponent('$orderNo|${time.toIso8601String()}');
  }
}
