import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class SyncLogStore extends PassStore {
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

String _publicSyncMessage(Map<String, dynamic> result) {
  if (result['status'] == 'running') return 'กำลังซิงก์เบื้องหลัง';
  final summary = result['summary'];
  if (summary is Map) return _publicSyncMessage(Map<String, dynamic>.from(summary));
  if (result['skipped'] == true) return 'เพิ่ง sync ไปแล้ว ข้ามรอบนี้';
  var orders = 0;
  var products = 0;
  final results = result['results'];
  if (results is List) {
    for (final row in results) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final o = m['orderCount'] ?? m['orders'] ?? m['OrderCount'];
      final p = m['productCount'] ?? m['products'] ?? m['ProductCount'];
      if (o is num) orders += o.toInt();
      if (p is num) products += p.toInt();
    }
  }
  final o = result['orderCount'] ?? result['orders'];
  final p = result['productCount'] ?? result['products'];
  if (o is num) orders += o.toInt();
  if (p is num) products += p.toInt();
  if (orders == 0 && products == 0) return 'ไม่มีข้อมูลใหม่';
  return 'ออเดอร์ใหม่ $orders สินค้า $products';
}

class MarketplaceSyncStore extends PassStore {
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
      lastMessage = _publicSyncMessage(result);
      final jobId = result['jobId']?.toString() ?? '';
      if (result['status'] == 'running' && jobId.isNotEmpty) {
        _watchJob(jobId);
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

  Future<void> _watchJob(String jobId) async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final job = await Api.syncJob(jobId);
        final status = job['status']?.toString() ?? '';
        if (status == 'running') continue;
        lastMessage = status == 'error'
            ? (job['error']?.toString() ?? 'ซิงก์ไม่สำเร็จ')
            : _publicSyncMessage(job);
        if (status == 'error') error = lastMessage;
        notifyListeners();
        return;
      } catch (_) {
        return;
      }
    }
  }
}
