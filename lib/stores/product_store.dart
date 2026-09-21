import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';
import 'sync_store.dart';

class ProductStore extends PassStore {
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
