class SapWarehouse {
  const SapWarehouse(this.code, [this.name = '']);

  final String code;
  final String name;

  String get label => name.isEmpty ? code : '$code — $name';
}

List<SapWarehouse> liveWarehouses = const [];

void setLiveWarehouses(List<SapWarehouse> rows) {
  final next = [for (final row in rows) if (row.code.trim().isNotEmpty) row];
  if (next.isEmpty) return;
  liveWarehouses = next;
}

List<SapWarehouse> parseWarehouses(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final row in raw)
      if (row is Map)
        SapWarehouse(
          pickWarehouseCode(row),
          pickWarehouseName(row),
        )
      else if ('$row'.trim().isNotEmpty)
        SapWarehouse('$row'.trim()),
  ].where((row) => row.code.isNotEmpty).toList();
}

String pickWarehouseCode(Map row) {
  for (final key in ['code', 'Code', 'WarehouseCode', 'warehouseCode', 'WhsCode']) {
    final value = row[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
  }
  return '';
}

String pickWarehouseName(Map row) {
  for (final key in ['name', 'Name', 'WarehouseName', 'warehouseName']) {
    final value = row[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
  }
  return '';
}

SapWarehouse? warehouseByCode(String code) {
  for (final w in liveWarehouses) {
    if (w.code == code) return w;
  }
  return null;
}

String warehouseLabel(String code) => warehouseByCode(code)?.label ?? code;
