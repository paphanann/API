import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

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
    final cleared = pickBool(m, ['Cleared', 'cleared']) == true;
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
    if (cleared || statusRaw == 'disconnected') {
      return ShopConn(
        channel: channel,
        status: ConnStatus.off,
        shop: '-',
        shopId: '-',
        lastConnected: null,
        lastSync: null,
        health: '-',
      );
    }
    final tokenMissing = hasToken == false || expired || askedReauth || dead.contains(statusRaw);
    final looksLive = statusRaw == 'connected' || statusRaw == 'live' || statusRaw == 'success';
    final connected = looksLive && !tokenMissing;
    final shop = pickStr(m, ['ShopName', 'shopName', 'shop_name', 'Name', 'Account', 'account']);
    // Lazada: แสดง Seller ID แยกจากอีเมลล็อกอิน — ถ้ามี SellerId ให้ใช้ก่อน
    final shopId = pickStr(
      m,
      channel == Channel.lazada
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
            ],
    );
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
