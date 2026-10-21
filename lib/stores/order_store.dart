import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';
import 'sync_store.dart';

class OrderStore extends PassStore {
  OrderStore._();
  static final instance = OrderStore._();

  List<Order> orders = [];
  bool loading = false;
  String? error;
  Future<void>? _inflight;

  Order? byId(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<Order?> loadOne(String id) async {
    final pending = _inflight;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    try {
      final one = await Api.getOrder(id);
      if (one == null) return byId(id);
      final i = orders.indexWhere((o) => o.id == id);
      if (i >= 0) {
        orders[i] = one;
      } else {
        orders = [...orders, one];
      }
      notifyListeners();
      return one;
    } catch (_) {
      return byId(id);
    }
  }

  Future<void> load({String? platform, String? shopId, bool silent = false}) async {
    if (_inflight != null) return _inflight!;
    _inflight = _load(platform: platform, shopId: shopId, silent: silent);
    try {
      await _inflight;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _load({String? platform, String? shopId, bool silent = false}) async {
    final showBusy = !silent || orders.isEmpty;
    if (showBusy) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final fresh = await Api.getOrders(platform: platform, shopId: shopId);
      final detailed = {for (final order in orders) if (order.lines.isNotEmpty) order.id: order};
      orders = [
        for (final order in fresh)
          if (order.lines.isEmpty && detailed.containsKey(order.id)) detailed[order.id]! else order,
      ];
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      if (orders.isEmpty) orders = [];
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
