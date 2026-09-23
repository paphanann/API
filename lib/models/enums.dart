enum OrderStatus { pending, success, cancelled }

enum ProductStatus { active, inactive, draft }

/// สถานะรอบ Sync — “ไม่พบการเปลี่ยนแปลง” อยู่ในข้อความ ไม่ใช่สถานะ
enum SyncStatus { running, success, partial, error }

enum ConnStatus { waiting, sandbox, live, off }
