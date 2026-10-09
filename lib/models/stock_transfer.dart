import '../core/json_util.dart';

class StockTransferLine {
  const StockTransferLine({required this.sku, required this.qty, this.name = ''});

  factory StockTransferLine.fromApi(Map<String, dynamic> m) {
    return StockTransferLine(
      sku: pickStr(m, ['Sku', 'sku', 'ItemCode', 'itemCode'], or: '-'),
      name: pickStr(m, ['Name', 'name', 'ItemName', 'itemName'], or: ''),
      qty: pickInt(m, ['Qty', 'qty', 'Quantity', 'quantity'], or: 0),
    );
  }

  final String sku;
  final String name;
  final int qty;

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'qty': qty,
        if (name.isNotEmpty) 'name': name,
      };
}

class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.items,
    this.fromWarehouseName = '',
    this.toWarehouseName = '',
    this.note = '',
    this.status = '',
    this.createdAt,
  });

  factory StockTransfer.fromApi(Map<String, dynamic> m) {
    final nested = pickList(m, ['Items', 'items', 'Lines', 'lines']);
    return StockTransfer(
      id: pickStr(m, ['Id', 'id', 'TransferNo', 'transferNo', 'DocNum', 'docNum'], or: '-'),
      fromWarehouseId: pickStr(m, ['FromWarehouseId', 'fromWarehouseId', 'FromWhs', 'fromWhs', 'From', 'from'], or: '-'),
      toWarehouseId: pickStr(m, ['ToWarehouseId', 'toWarehouseId', 'ToWhs', 'toWhs', 'To', 'to'], or: '-'),
      fromWarehouseName: pickStr(m, ['FromWarehouseName', 'fromWarehouseName', 'FromWhsName'], or: ''),
      toWarehouseName: pickStr(m, ['ToWarehouseName', 'toWarehouseName', 'ToWhsName'], or: ''),
      items: [
        for (final row in nested)
          if (row is Map) StockTransferLine.fromApi(Map<String, dynamic>.from(row)),
      ],
      note: pickStr(m, ['Note', 'note', 'Remark', 'remark', 'Comments'], or: ''),
      status: pickStr(m, ['Status', 'status'], or: ''),
      createdAt: pickTime(m, ['CreatedAt', 'createdAt', 'TransferDate', 'transferDate', 'Date', 'date']),
    );
  }

  final String id;
  final String fromWarehouseId;
  final String toWarehouseId;
  final String fromWarehouseName;
  final String toWarehouseName;
  final List<StockTransferLine> items;
  final String note;
  final String status;
  final DateTime? createdAt;

  int get qtyTotal => items.fold(0, (a, i) => a + i.qty);

  String get fromLabel => fromWarehouseName.isNotEmpty && fromWarehouseName != '-' ? fromWarehouseName : fromWarehouseId;
  String get toLabel => toWarehouseName.isNotEmpty && toWarehouseName != '-' ? toWarehouseName : toWarehouseId;
}
