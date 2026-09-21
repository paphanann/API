import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class DashStore extends PassStore {
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
