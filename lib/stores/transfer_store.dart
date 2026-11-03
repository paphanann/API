import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';

class TransferStore extends PassStore {
  TransferStore._();
  static final instance = TransferStore._();

  List<StockTransfer> rows = [];
  bool loading = false;
  bool saving = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      rows = await Api.getStockTransfers();
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      rows = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<StockTransfer> create({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<StockTransferLine> items,
    String note = '',
    String documentNo = '',
    String referenceNo = '',
    String requestedBy = '',
    DateTime? dueDate,
    String? platform,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final row = await Api.createStockTransfer(
        fromWarehouseId: fromWarehouseId,
        toWarehouseId: toWarehouseId,
        items: items,
        note: note,
        documentNo: documentNo,
        referenceNo: referenceNo,
        requestedBy: requestedBy,
        dueDate: dueDate,
        createdAt: now,
        platform: platform,
      );
      final stamped = row.hasClock ? row : row.copyWith(createdAt: now);
      rows = [stamped, ...rows];
      return stamped;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
