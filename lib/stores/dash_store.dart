import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class DashStore extends PassStore {
  DashStore._();
  static final instance = DashStore._();

  DashData data = DashData.empty();
  bool loading = false;
  String? error;
  DateTime? _from;
  DateTime? _to;
  String? _platform;
  String? _shopId;

  Future<void> load({
    DateTime? from,
    DateTime? to,
    String? platform,
    String? shopId,
    bool keepFilter = false,
  }) async {
    if (!keepFilter) {
      _from = from;
      _to = to;
      _platform = platform;
      _shopId = shopId;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await Api.getDashboard(from: _from, to: _to, platform: _platform, shopId: _shopId);
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      data = DashData.empty();
    }
    loading = false;
    notifyListeners();
  }
}
