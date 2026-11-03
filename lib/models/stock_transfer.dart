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
    this.dueDate,
    this.referenceNo = '',
    this.requestedBy = '',
    this.platform = '',
    this.salesOrderIds = const [],
    this.sapDocNum = '',
  });

  factory StockTransfer.fromApi(Map<String, dynamic> m) {
    final nested = pickList(m, ['Items', 'items', 'Lines', 'lines']);
    return StockTransfer(
      id: pickStr(m, ['Id', 'id', 'TransferNo', 'transferNo', 'DocNum', 'docNum', 'DocEntry'], or: '-'),
      fromWarehouseId: pickStr(m, ['FromWarehouseId', 'fromWarehouseId', 'FromWhs', 'fromWhs', 'From', 'from'], or: '-'),
      toWarehouseId: pickStr(m, ['ToWarehouseId', 'toWarehouseId', 'ToWhs', 'toWhs', 'To', 'to'], or: '-'),
      fromWarehouseName: pickStr(m, ['FromWarehouseName', 'fromWarehouseName', 'FromWhsName'], or: ''),
      toWarehouseName: pickStr(m, ['ToWarehouseName', 'toWarehouseName', 'ToWhsName'], or: ''),
      items: [
        for (final row in nested)
          if (row is Map) StockTransferLine.fromApi(Map<String, dynamic>.from(row)),
      ],
      note: pickStr(m, ['Note', 'note', 'Remark', 'remark', 'Comments', 'Reason', 'reason'], or: ''),
      status: pickStr(m, ['Status', 'status'], or: ''),
      createdAt: _createdAt(m),
      dueDate: pickTime(m, ['DueDate', 'dueDate', 'DocDueDate', 'docDueDate', 'TaxDate', 'taxDate']),
      referenceNo: pickStr(m, ['ReferenceNo', 'referenceNo', 'NumAtCard', 'numAtCard', 'Ref', 'ref'], or: ''),
      requestedBy: pickStr(m, ['RequestedBy', 'requestedBy', 'Requester', 'requester', 'OwnerName', 'ownerName', 'UserName', 'userName'], or: ''),
      platform: pickStr(m, ['Platform', 'platform', 'Channel', 'channel'], or: ''),
      salesOrderIds: [
        for (final row in pickList(m, ['salesOrderIds', 'SalesOrderIds']))
          if (row != null && row.toString().trim().isNotEmpty) row.toString().trim(),
      ],
      sapDocNum: pickStr(m, ['sapDocNum', 'SapDocNum', 'DocNum', 'docNum'], or: ''),
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
  final DateTime? dueDate;
  final String referenceNo;
  final String requestedBy;
  final String platform;
  final List<String> salesOrderIds;
  final String sapDocNum;

  DateTime? get scheduleDate => createdAt ?? dueDate;

  DateTime? get displayAt => createdAt ?? dueDate;

  int get qtyTotal => items.fold(0, (a, i) => a + i.qty);

  String get fromLabel => fromWarehouseName.isNotEmpty && fromWarehouseName != '-' ? fromWarehouseName : fromWarehouseId;
  String get toLabel => toWarehouseName.isNotEmpty && toWarehouseName != '-' ? toWarehouseName : toWarehouseId;

  bool get hasClock => displayAt != null && (displayAt!.hour != 0 || displayAt!.minute != 0);

  StockTransfer copyWith({DateTime? createdAt}) {
    return StockTransfer(
      id: id,
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      items: items,
      fromWarehouseName: fromWarehouseName,
      toWarehouseName: toWarehouseName,
      note: note,
      status: status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate,
      referenceNo: referenceNo,
      requestedBy: requestedBy,
      platform: platform,
      salesOrderIds: salesOrderIds,
      sapDocNum: sapDocNum,
    );
  }
}

DateTime? _createdAt(Map<String, dynamic> m) {
  var at = pickTime(m, [
    'CreatedAt',
    'createdAt',
    'CreatedOn',
    'createdOn',
    'UpdatedAt',
    'updatedAt',
  ]);
  at ??= pickTime(m, [
    'CreateDate',
    'createDate',
    'CreationDate',
    'creationDate',
    'TransferDate',
    'transferDate',
    'Date',
    'date',
    'DocDate',
    'docDate',
  ]);
  return _withSapClock(at, m);
}

DateTime? _withSapClock(DateTime? date, Map<String, dynamic> m) {
  if (date == null) return null;
  final v = pick(m, [
    'CreateTime',
    'createTime',
    'CreationTime',
    'creationTime',
    'CreatedTime',
    'createdTime',
    'DocTime',
    'docTime',
    'UpdateTime',
    'updateTime',
  ]);
  if (v == null) return date;
  final clock = _parseSapClock(v);
  if (clock == null) return date;
  return DateTime(date.year, date.month, date.day, clock.$1, clock.$2, clock.$3);
}

(int, int, int)? _parseSapClock(dynamic v) {
  var h = 0, min = 0, s = 0;
  if (v is Duration) {
    return (v.inHours, v.inMinutes % 60, v.inSeconds % 60);
  }
  if (v is DateTime) {
    return (v.hour, v.minute, v.second);
  }
  if (v is num) {
    final n = v.toInt().abs();
    if (n >= 10000) {
      h = n ~/ 10000;
      min = (n ~/ 100) % 100;
      s = n % 100;
    } else if (n > 2359) {
      h = n ~/ 60;
      min = n % 60;
    } else {
      h = n ~/ 100;
      min = n % 100;
      if (min > 59) {
        h = n ~/ 60;
        min = n % 60;
      }
    }
  } else {
    final raw = v.toString().trim();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return (iso.hour, iso.minute, iso.second);
    final parts = raw.split(RegExp(r'[:.]'));
    if (parts.length >= 2) {
      h = int.tryParse(parts[0]) ?? 0;
      min = int.tryParse(parts[1]) ?? 0;
      s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    } else {
      final n = int.tryParse(raw.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (n <= 0) return null;
      return _parseSapClock(n);
    }
  }
  if (h > 23 || min > 59 || s > 59) return null;
  return (h, min, s);
}
