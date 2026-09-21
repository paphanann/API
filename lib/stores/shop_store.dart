import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class ShopStore extends PassStore {
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
