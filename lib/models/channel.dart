import 'package:flutter/material.dart';

import '../app/theme.dart';

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
