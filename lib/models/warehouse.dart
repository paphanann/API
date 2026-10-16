class SapWarehouse {
  const SapWarehouse(this.code, [this.name = '']);

  final String code;
  final String name;

  String get label => name.isEmpty ? code : '$code — $name';
}

/// คลังจาก SAP Business One (OWHS)
const sapWarehouses = [
  SapWarehouse('01'),
  SapWarehouse('C01-RT'),
  SapWarehouse('C02-PR9'),
  SapWarehouse('C03-HOLD'),
  SapWarehouse('C04-CM'),
];

SapWarehouse? warehouseByCode(String code) {
  for (final w in sapWarehouses) {
    if (w.code == code) return w;
  }
  return null;
}

String warehouseLabel(String code) => warehouseByCode(code)?.label ?? code;
