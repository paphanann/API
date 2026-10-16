import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

class ShopConn {
  const ShopConn({
    required this.channel,
    required this.status,
    required this.shop,
    required this.shopId,
    this.recordShopId = '',
    required this.lastConnected,
    required this.lastSync,
    required this.health,
    this.needsReauth = false,
    this.country = '',
    this.group = '',
    this.warehouse = '',
    this.note = '',
    this.tokenExpiresAt,
  });

  factory ShopConn.empty(Channel channel) {
    return ShopConn(
      channel: channel,
      status: ConnStatus.waiting,
      shop: '-',
      shopId: '-',
      recordShopId: '',
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
    final tokenMissing = hasToken == false || expired || askedReauth || dead.contains(statusRaw);
    final looksLive = statusRaw == 'connected' || statusRaw == 'live' || statusRaw == 'success';
    final connected = looksLive && !tokenMissing;
    final shop = pickStr(m, ['ShopName', 'shopName', 'shop_name', 'Name', 'Account', 'account']);
    final recordShopId = pickStr(m, ['ShopId', 'shopId', 'shop_id'], or: '');
    final sellerId = pickStr(m, ['SellerId', 'sellerId', 'seller_id'], or: '');
    // Lazada: ช่อง Shop ID บนหน้าเชื่อมต่อโชว์ Seller ID ส่วนตัวกรองสินค้าใช้ ShopId จริง
    final shopId = channel == Channel.lazada && sellerId.isNotEmpty && sellerId != '-'
        ? sellerId
        : (recordShopId.isNotEmpty && recordShopId != '-'
            ? recordShopId
            : pickStr(m, ['OpenId', 'openId'], or: sellerId));
    final hadShop = (shop.isNotEmpty && shop != '-') || (shopId.isNotEmpty && shopId != '-');
    final disconnected = statusRaw == 'disconnected';
    if ((cleared || statusRaw == 'disconnected') && !hadShop) {
      return ShopConn(
        channel: channel,
        status: ConnStatus.off,
        shop: '-',
        shopId: '-',
        recordShopId: '',
        lastConnected: null,
        lastSync: null,
        health: '-',
      );
    }
    String opt(List<String> keys) {
      final v = pickStr(m, keys, or: '');
      return v == '-' ? '' : v;
    }

    return ShopConn(
      channel: channel,
      status: connected
          ? ConnStatus.live
          : (!disconnected && tokenMissing && (looksLive || hadShop) ? ConnStatus.waiting : ConnStatus.off),
      shop: shop,
      shopId: shopId,
      recordShopId: recordShopId == '-' ? '' : recordShopId,
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
      needsReauth: !disconnected && tokenMissing && (looksLive || hadShop || statusRaw == 'expired'),
      country: opt(['Country', 'country', 'Region', 'region', 'ShopRegion', 'shopRegion']),
      group: opt(['Group', 'group', 'ShopGroup', 'shopGroup', 'ProductGroup', 'productGroup']),
      warehouse: opt(['Warehouse', 'warehouse', 'WhsCode', 'whsCode', 'WarehouseCode', 'warehouseCode']),
      note: opt(['Note', 'note', 'Remark', 'remark', 'Description', 'description']),
      tokenExpiresAt: pickTime(m, [
        'TokenExpiresAt',
        'tokenExpiresAt',
        'ExpireTime',
        'expireTime',
        'AccessTokenExpireAt',
        'accessTokenExpireAt',
        'RefreshExpireAt',
        'refreshExpireAt',
      ]),
    );
  }

  final Channel channel;
  final ConnStatus status;
  final String shop;
  final String shopId;
  final String recordShopId;
  final DateTime? lastConnected;
  final DateTime? lastSync;
  final String health;
  final bool needsReauth;
  final String country;
  final String group;
  final String warehouse;
  final String note;
  final DateTime? tokenExpiresAt;

  String get idLabel => channel == Channel.lazada ? 'Seller ID' : 'Shop ID';

  bool get connected => status == ConnStatus.live || status == ConnStatus.sandbox;

  bool get isReal => (shopId.isNotEmpty && shopId != '-') || (shop.isNotEmpty && shop != '-');

  String get displayName => shop.isEmpty || shop == '-' ? channel.label : shop;

  /// รหัสร้านในฐานข้อมูล ใช้จับคู่สินค้าและคำสั่งซื้อ
  String get apiShopId {
    final record = recordShopId.trim();
    if (record.isNotEmpty && record != '-') return record;
    final shown = shopId.trim();
    if (shown.isNotEmpty && shown != '-') return shown;
    return '';
  }

  Set<String> get identityKeys => {
        for (final v in [apiShopId, shopId, shop, displayName])
          if (v.trim().isNotEmpty && v.trim() != '-') v.trim().toLowerCase(),
      };

  String get detailPath => '/connections/${channel.name}/${Uri.encodeComponent(shopId)}';

  ShopConn copyWith({
    String? shop,
    String? country,
    String? group,
    String? warehouse,
    String? note,
    DateTime? tokenExpiresAt,
    bool clearTokenExpiresAt = false,
  }) {
    return ShopConn(
      channel: channel,
      status: status,
      shop: shop ?? this.shop,
      shopId: shopId,
      recordShopId: recordShopId,
      lastConnected: lastConnected,
      lastSync: lastSync,
      health: health,
      needsReauth: needsReauth,
      country: country ?? this.country,
      group: group ?? this.group,
      warehouse: warehouse ?? this.warehouse,
      note: note ?? this.note,
      tokenExpiresAt: clearTokenExpiresAt ? null : (tokenExpiresAt ?? this.tokenExpiresAt),
    );
  }
}
