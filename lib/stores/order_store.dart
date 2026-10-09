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

  Order? byId(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<Order?> loadOne(String id) async {
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

  Future<void> load({String? platform}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      orders = await Api.getOrders(platform: platform);
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
