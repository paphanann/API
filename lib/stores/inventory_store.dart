import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class InventoryStore extends PassStore {
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
