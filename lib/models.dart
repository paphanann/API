import 'package:flutter/material.dart';

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
  });

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

  double get total {
    var sum = 0.0;
    for (final line in lines) {
      sum += line.amount;
    }
    return sum;
  }
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

  final String sku;
  final String name;
  final Channel channel;
  final double price;
  final int stock;
  final ProductStatus status;
  final bool synced;
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
    required this.partnerId,
    required this.mode,
    required this.accessToken,
    required this.refreshToken,
    required this.lastConnected,
    required this.lastSync,
    required this.health,
  });

  final Channel channel;
  final ConnStatus status;
  final String shop;
  final String shopId;
  final String partnerId;
  final String mode;
  final String accessToken;
  final String refreshToken;
  final DateTime? lastConnected;
  final DateTime? lastSync;
  final String health;

  String get idLabel => channel == Channel.lazada ? 'Seller ID' : 'Shop ID';
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
  });

  final DateTime time;
  final Channel channel;
  final String orderNo;
  final String action;
  final SyncStatus status;
  final String msg;
  final String? docEntry;
  final String? docNum;
}
