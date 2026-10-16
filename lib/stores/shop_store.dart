import 'dart:convert';

import 'package:web/web.dart' as web;

import '../core/api.dart';
import '../models/models.dart';
import 'dash_store.dart';
import 'order_store.dart';
import 'pass_store.dart';
import 'product_store.dart';

class ShopStore extends PassStore {
  ShopStore._();
  static final instance = ShopStore._();

  List<ShopConn> shops = [for (final c in Channel.values) ShopConn.empty(c)];
  bool loading = false;
  String? error;
  String? success;
  Channel? syncing;
  ShopConn? lastConnectedShop;
  bool showConnectSuccess = false;

  List<ShopConn> get realShops => [for (final s in shops) if (s.isReal) s];

  String nameFor({required Channel channel, String shopId = '', String shopName = ''}) {
    ShopConn? hit;
    final id = shopId.trim().toLowerCase();
    if (id.isNotEmpty && id != '-') {
      for (final s in realShops) {
        if (s.channel != channel) continue;
        if (s.identityKeys.contains(id)) {
          hit = s;
          break;
        }
      }
    }
    final named = shopName.trim();
    if (hit == null && named.isNotEmpty && named != '-') {
      for (final s in realShops) {
        if (s.channel != channel) continue;
        if (s.identityKeys.contains(named.toLowerCase())) {
          hit = s;
          break;
        }
      }
    }
    hit ??= () {
      final same = [for (final s in realShops) if (s.isReal && s.channel == channel) s];
      return same.length == 1 ? same.first : null;
    }();
    if (hit != null) return hit.displayName;
    if (named.isNotEmpty && named != '-') return named;
    return '-';
  }

  ShopConn? findShop(String channelName, String shopId) {
    var id = shopId.trim();
    try {
      id = Uri.decodeComponent(id);
    } catch (_) {}
    final ch = channelName.trim().toLowerCase();
    for (final s in realShops) {
      final sameId = s.shopId == id || s.shopId == shopId;
      final sameCh = s.channel.name == ch || s.channel.apiSlug == ch || s.channel.label.toLowerCase() == ch;
      if (sameId && sameCh) return withMeta(s);
    }
    return null;
  }

  ShopConn withMeta(ShopConn shop) {
    final raw = web.window.localStorage.getItem(_metaKey(shop));
    if (raw == null || raw.isEmpty) return shop;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return shop;
      final map = Map<String, dynamic>.from(m);
      return shop.copyWith(
        country: '${map['country'] ?? ''}'.trim().isNotEmpty ? '${map['country']}' : shop.country,
        group: '${map['group'] ?? ''}'.trim().isNotEmpty ? '${map['group']}' : shop.group,
        warehouse: '${map['warehouse'] ?? ''}'.trim().isNotEmpty ? '${map['warehouse']}' : shop.warehouse,
        note: '${map['note'] ?? ''}'.trim().isNotEmpty ? '${map['note']}' : shop.note,
      );
    } catch (_) {
      return shop;
    }
  }

  void saveMeta(ShopConn shop, {required String country, required String group, required String warehouse, required String note}) {
    web.window.localStorage.setItem(
      _metaKey(shop),
      jsonEncode({'country': country, 'group': group, 'warehouse': warehouse, 'note': note}),
    );
    shops = [for (final s in shops) if (s.channel == shop.channel && s.shopId == shop.shopId) s.copyWith(country: country, group: group, warehouse: warehouse, note: note) else s];
    notifyListeners();
  }

  String _metaKey(ShopConn shop) => 'pass_shop_meta_${shop.channel.name}_${shop.shopId}';

  ShopConn? latestLive({String? shopId, String? channelName}) {
    final id = (shopId ?? '').trim();
    final ch = (channelName ?? '').trim().toLowerCase();
    final live = [for (final s in realShops) if (s.connected) s];
    if (id.isNotEmpty && id != '-') {
      for (final s in live) {
        if (s.shopId == id && (ch.isEmpty || s.channel.name == ch || s.channel.apiSlug == ch)) return s;
      }
    }
    live.sort((a, b) => (b.lastConnected ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.lastConnected ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return live.isEmpty ? null : live.first;
  }

  void markConnectSuccess(ShopConn? shop) {
    lastConnectedShop = shop;
    showConnectSuccess = shop != null;
    success = shop == null ? null : 'เชื่อมต่อร้านค้าสำเร็จ';
    error = null;
    notifyListeners();
  }

  void dismissConnectSuccess() {
    showConnectSuccess = false;
    lastConnectedShop = null;
    success = null;
    notifyListeners();
  }

  void setError(String message) {
    error = message;
    success = null;
    notifyListeners();
  }

  void setSuccess(String message) {
    success = message;
    error = null;
    notifyListeners();
  }

  ShopConn byChannel(Channel channel) {
    for (final s in shops) {
      if (s.channel == channel) return s;
    }
    return ShopConn.empty(channel);
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Api.checkHealth();
    } on ApiException catch (e) {
      error = e.statusCode == null ? 'เซิร์ฟเวอร์ล่ม: ${e.message}' : e.message;
      shops = [for (final c in Channel.values) ShopConn.empty(c)];
      loading = false;
      notifyListeners();
      return;
    } catch (e) {
      error = 'เซิร์ฟเวอร์ล่ม: $e';
      shops = [for (final c in Channel.values) ShopConn.empty(c)];
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final rows = await Api.getConnections();
      shops = [
        for (final c in Channel.values) ...<ShopConn>[
          if (rows.any((s) => s.channel == c && s.shopId != '-'))
            ...rows.where((s) => s.channel == c && s.shopId != '-')
          else
            ShopConn.empty(c),
        ],
      ];
    } catch (e) {
      error = e is ApiException ? e.message : 'SQL ล้มเหลว: $e';
      shops = [for (final c in Channel.values) ShopConn.empty(c)];
    }
    loading = false;
    notifyListeners();
  }

  Future<void> sync(Channel channel) async {
    syncing = channel;
    error = null;
    notifyListeners();
    try {
      await Api.syncPlatform(channel);
      await load();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    syncing = null;
    notifyListeners();
  }

  Future<void> remove(Channel channel, {String? shopId}) async {
    loading = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final msg = await Api.removeShop(channel, shopId: shopId);
      await load();
      await Future.wait([
        ProductStore.instance.load(),
        OrderStore.instance.load(),
        DashStore.instance.load(),
      ]);
      success = msg;
      notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> disconnect(Channel channel, {String? shopId}) async {
    loading = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final msg = await Api.disconnectPlatform(channel, shopId: shopId);
      await load();
      await Future.wait([
        ProductStore.instance.load(),
        OrderStore.instance.load(),
        DashStore.instance.load(),
      ]);
      success = msg;
      notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      loading = false;
      notifyListeners();
    }
  }
}
