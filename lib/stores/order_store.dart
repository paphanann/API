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
