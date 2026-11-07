enum OrderStatus { unpaid, pending, shipping, success, cancelled, returned }

enum ProductStatus { active, inactive, draft }

/// สถานะจับคู่ SKU กับ SAP
enum MappingStatus { mapped, partial, unmapped, noSku }

extension MappingStatusX on MappingStatus {
  String get label {
    switch (this) {
      case MappingStatus.mapped:
        return 'จับคู่แล้ว';
      case MappingStatus.partial:
        return 'จับคู่บางส่วน';
      case MappingStatus.unmapped:
        return 'ยังไม่จับคู่';
      case MappingStatus.noSku:
        return 'ไม่มี SKU';
    }
  }
}

/// สถานะรอบ Sync — “ไม่พบการเปลี่ยนแปลง” อยู่ในข้อความ ไม่ใช่สถานะ
enum SyncStatus { running, success, partial, error }

enum ConnStatus { waiting, sandbox, live, off }
