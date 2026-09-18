import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

class ShopStore extends ChangeNotifier {
  ShopStore._();
  static final instance = ShopStore._();

  List<ShopConn> shops = [for (final c in Channel.values) ShopConn.empty(c)];
  bool loading = false;
  String? error;
  String? success;
  Channel? syncing;

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
        for (final c in Channel.values)
          rows.where((s) => s.channel == c).followedBy([ShopConn.empty(c)]).first,
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

  Future<void> disconnect(Channel channel) async {
    loading = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final msg = await Api.disconnectPlatform(channel);
      await load();
      success = msg;
      notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      loading = false;
      notifyListeners();
    }
  }
}

class OrderStore extends ChangeNotifier {
  OrderStore._();
  static final instance = OrderStore._();

  List<Order> orders = [];
  bool loading = false;
  String? error;

  Order? byId(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> load({String? platform}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (platform == null) {
        final chunks = await Future.wait([
          Api.getOrders(platform: Channel.shopee.apiPlatform),
          Api.getOrders(platform: Channel.tiktok.apiPlatform),
          Api.getOrders(platform: Channel.lazada.apiPlatform),
        ]);
        orders = [for (final chunk in chunks) ...chunk];
      } else {
        orders = await Api.getOrders(platform: platform);
      }
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      orders = [];
    }
    loading = false;
    notifyListeners();
  }

  /// โหลดจาก DB ก่อน แล้ว sync จากแพลตฟอร์มพื้นหลังแล้วรีโหลด
  Future<void> loadAndSync({String? platform}) async {
    await load(platform: platform);
    await MarketplaceSyncStore.instance.syncNow(quiet: true);
    await load(platform: platform);
  }
}

class SyncLogStore extends ChangeNotifier {
  SyncLogStore._();
  static final instance = SyncLogStore._();

  List<SyncRow> logs = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      logs = await Api.getSyncLogs();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      logs = [];
    }
    loading = false;
    notifyListeners();
  }

  SyncRow? byRouteId(String id) {
    for (final l in logs) {
      if (l.routeId == id || l.id == id) return l;
    }
    return null;
  }
}

class DashStore extends ChangeNotifier {
  DashStore._();
  static final instance = DashStore._();

  DashData data = DashData.empty();
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      var dash = await Api.getDashboard();
      if (!dash.hasStats || !dash.hasCharts) {
        try {
          dash = dash.merge(await Api.dashboardFromLive());
        } catch (_) {}
      }
      data = dash;
    } catch (e) {
      try {
        data = await Api.dashboardFromLive();
      } catch (_) {
        error = e is ApiException ? e.message : e.toString();
        data = DashData.empty();
      }
    }
    loading = false;
    notifyListeners();
  }
}

class MarketplaceSyncStore extends ChangeNotifier {
  MarketplaceSyncStore._();
  static final instance = MarketplaceSyncStore._();

  bool syncing = false;
  String? error;
  String? lastMessage;

  Future<Map<String, dynamic>?> syncNow({bool quiet = false, bool force = false}) async {
    if (syncing) return null;
    syncing = true;
    error = null;
    if (!quiet) notifyListeners();
    try {
      final result = await Api.syncNow(force: force);
      if (result['skipped'] == true) {
        lastMessage = result['message']?.toString() ?? 'เพิ่ง sync ไปแล้ว ข้ามรอบนี้';
        return result;
      }
      final results = result['results'];
      if (results is List && results.isNotEmpty) {
        final parts = <String>[];
        for (final row in results) {
          if (row is Map && row['message'] != null) {
            parts.add('${row['platform'] ?? ''}: ${row['message']}');
          }
        }
        lastMessage = parts.isNotEmpty ? parts.join(' | ') : (result['message']?.toString() ?? 'Sync แล้ว');
      } else {
        lastMessage = result['message']?.toString() ?? 'Sync แล้ว';
      }
      return result;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      lastMessage = null;
      if (!quiet) rethrow;
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

class ProductStore extends ChangeNotifier {
  ProductStore._();
  static final instance = ProductStore._();

  List<Product> products = [];
  bool loading = false;
  String? error;

  Future<void> load({String? platform}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (platform == null) {
        final chunks = await Future.wait([
          Api.getProducts(platform: Channel.shopee.apiPlatform),
          Api.getProducts(platform: Channel.tiktok.apiPlatform),
          Api.getProducts(platform: Channel.lazada.apiPlatform),
        ]);
        products = [for (final c in chunks) ...c];
      } else {
        products = await Api.getProducts(platform: platform);
      }
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      products = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadAndSync({String? platform}) async {
    await load(platform: platform);
    await MarketplaceSyncStore.instance.syncNow(quiet: true);
    await load(platform: platform);
  }
}

class InventoryStore extends ChangeNotifier {
  InventoryStore._();
  static final instance = InventoryStore._();

  List<StockRow> rows = [];
  bool loading = false;
  String? error;

  Future<void> load({String? warehouse, String? platform}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      rows = await Api.getInventory(warehouse: warehouse, platform: platform);
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      rows = [];
    }
    loading = false;
    notifyListeners();
  }
}
