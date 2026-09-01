import 'models.dart';

// ข้อมูลตัวอย่างทั้งก้อน เดี๋ยวค่อยย้ายไป API
class Dummy {
  static const totalOrders = 245;
  static const pendingOrders = 38;
  static const successOrders = 186;
  static const connected = 2;

  static const weekLabels = ['26 เม.ย.', '27 เม.ย.', '28 เม.ย.', '29 เม.ย.', '30 เม.ย.', '1 พ.ค.', '2 พ.ค.'];
  static const shopeeWeek = [18.0, 24.0, 21.0, 32.0, 28.0, 36.0, 30.0];
  static const tiktokWeek = [12.0, 15.0, 19.0, 16.0, 22.0, 20.0, 26.0];

  static final orders = <Order>[
    Order(
      id: 'TT-240505-0001',
      channel: Channel.tiktok,
      customer: 'สมชาย ใจดี',
      phone: '081-234-5678',
      address: '99/12 ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
      createdAt: DateTime(2024, 5, 5, 14, 32),
      status: OrderStatus.success,
      payment: 'TikTok Pay',
      shipping: 'Kerry Express',
      lines: const [
        OrderLine(sku: 'SKU-TT-1001', name: 'เสื้อยืดคอกลม สีขาว', qty: 2, price: 259),
        OrderLine(sku: 'SKU-TT-2044', name: 'กางเกงขาสั้น ผ้าฝ้าย', qty: 1, price: 390),
      ],
    ),
    Order(
      id: 'SHO-240505-0001',
      channel: Channel.shopee,
      customer: 'วิภาดา พูนสุข',
      phone: '089-551-2201',
      address: '18 หมู่ 4 ต.บางรัก อ.เมือง จ.สมุทรปราการ 10270',
      createdAt: DateTime(2024, 5, 5, 11, 18),
      status: OrderStatus.pending,
      payment: 'Shopee Pay',
      shipping: 'Shopee Express',
      lines: const [
        OrderLine(sku: 'SKU-SH-3302', name: 'กระเป๋าสะพายข้าง', qty: 1, price: 890),
      ],
    ),
    Order(
      id: 'SHO-240504-0018',
      channel: Channel.shopee,
      customer: 'กิตติพงศ์ แสงทอง',
      phone: '086-778-4410',
      address: '201 ถ.นิมมานเหมินท์ ต.สุเทพ อ.เมือง จ.เชียงใหม่ 50200',
      createdAt: DateTime(2024, 5, 4, 19, 5),
      status: OrderStatus.success,
      payment: 'บัตรเครดิต',
      shipping: 'Thai Post EMS',
      lines: const [
        OrderLine(sku: 'SKU-SH-1188', name: 'หูฟังบลูทูธ TWS', qty: 1, price: 1290),
        OrderLine(sku: 'SKU-SH-0091', name: 'เคสกันกระแทก', qty: 2, price: 159),
      ],
    ),
    Order(
      id: 'TT-240504-0007',
      channel: Channel.tiktok,
      customer: 'นภา ศรีสุข',
      phone: '092-334-8890',
      address: '55/8 ถ.รัชดาภิเษก แขวงดินแดง เขตดินแดง กรุงเทพฯ 10400',
      createdAt: DateTime(2024, 5, 4, 16, 41),
      status: OrderStatus.cancelled,
      payment: 'COD',
      shipping: 'Flash Express',
      lines: const [
        OrderLine(sku: 'SKU-TT-5510', name: 'ครีมบำรุงผิว 50ml', qty: 3, price: 320),
      ],
    ),
    Order(
      id: 'LAZ-240503-0003',
      channel: Channel.lazada,
      customer: 'อรุณ มาลี',
      phone: '083-990-1122',
      address: '12 ซอยลาดพร้าว 71 แขวงลาดพร้าว เขตลาดพร้าว กรุงเทพฯ 10230',
      createdAt: DateTime(2024, 5, 3, 9, 12),
      status: OrderStatus.pending,
      payment: 'Lazada Wallet',
      shipping: 'LEX',
      lines: const [
        OrderLine(sku: 'SKU-LZ-7701', name: 'หม้อทอดไร้น้ำมัน 4.5L', qty: 1, price: 2490),
      ],
    ),
    Order(
      id: 'SHO-240503-0009',
      channel: Channel.shopee,
      customer: 'ปิยะนุช จันทร์เพ็ญ',
      phone: '061-445-7788',
      address: '88 ถ.เพชรเกษม ต.หาดใหญ่ อ.หาดใหญ่ จ.สงขลา 90110',
      createdAt: DateTime(2024, 5, 3, 8, 27),
      status: OrderStatus.success,
      payment: 'โอนธนาคาร',
      shipping: 'J&T Express',
      lines: const [
        OrderLine(sku: 'SKU-SH-2210', name: 'รองเท้าผ้าใบ ไซซ์ 39', qty: 1, price: 790),
        OrderLine(sku: 'SKU-SH-2211', name: 'ถุงเท้ากีฬา 3 คู่', qty: 1, price: 129),
      ],
    ),
    Order(
      id: 'TT-240502-0012',
      channel: Channel.tiktok,
      customer: 'ธนพล วัฒนา',
      phone: '084-220-6677',
      address: '3/15 ถ.มิตรภาพ ต.ในเมือง อ.เมือง จ.ขอนแก่น 40000',
      createdAt: DateTime(2024, 5, 2, 21, 3),
      status: OrderStatus.success,
      payment: 'TikTok Pay',
      shipping: 'SPX Express',
      lines: const [
        OrderLine(sku: 'SKU-TT-8802', name: 'แก้วเก็บความเย็น 20oz', qty: 2, price: 450),
      ],
    ),
    Order(
      id: 'SHO-240501-0025',
      channel: Channel.shopee,
      customer: 'มณีรัตน์ ทองดี',
      phone: '098-111-3344',
      address: '70 หมู่บ้านสวนสยาม เขตคันนายาว กรุงเทพฯ 10230',
      createdAt: DateTime(2024, 5, 1, 13, 55),
      status: OrderStatus.pending,
      payment: 'Shopee PayLater',
      shipping: 'Shopee Express',
      lines: const [
        OrderLine(sku: 'SKU-SH-4408', name: 'ชุดเครื่องนอน 6 ฟุต', qty: 1, price: 1590),
      ],
    ),
  ];

  static final products = <Product>[
    const Product(sku: 'SKU-SH-3302', name: 'กระเป๋าสะพายข้าง', channel: Channel.shopee, price: 890, stock: 42, status: ProductStatus.active, synced: true),
    const Product(sku: 'SKU-TT-1001', name: 'เสื้อยืดคอกลม สีขาว', channel: Channel.tiktok, price: 259, stock: 180, status: ProductStatus.active, synced: true),
    const Product(sku: 'SKU-SH-1188', name: 'หูฟังบลูทูธ TWS', channel: Channel.shopee, price: 1290, stock: 24, status: ProductStatus.active, synced: true),
    const Product(sku: 'SKU-LZ-7701', name: 'หม้อทอดไร้น้ำมัน 4.5L', channel: Channel.lazada, price: 2490, stock: 8, status: ProductStatus.active, synced: false),
    const Product(sku: 'SKU-TT-5510', name: 'ครีมบำรุงผิว 50ml', channel: Channel.tiktok, price: 320, stock: 0, status: ProductStatus.inactive, synced: true),
    const Product(sku: 'SKU-SH-2210', name: 'รองเท้าผ้าใบ ไซซ์ 39', channel: Channel.shopee, price: 790, stock: 15, status: ProductStatus.active, synced: true),
    const Product(sku: 'SKU-TT-8802', name: 'แก้วเก็บความเย็น 20oz', channel: Channel.tiktok, price: 450, stock: 67, status: ProductStatus.active, synced: true),
    const Product(sku: 'SKU-SH-4408', name: 'ชุดเครื่องนอน 6 ฟุต', channel: Channel.shopee, price: 1590, stock: 11, status: ProductStatus.draft, synced: false),
  ];

  static final stocks = <StockRow>[
    const StockRow(sku: 'SKU-SH-3302', name: 'กระเป๋าสะพายข้าง', wh: 'BKK-01', available: 38, reserved: 4, shopee: true, tiktok: false, lazada: false),
    const StockRow(sku: 'SKU-TT-1001', name: 'เสื้อยืดคอกลม สีขาว', wh: 'BKK-01', available: 160, reserved: 20, shopee: true, tiktok: true, lazada: false),
    const StockRow(sku: 'SKU-SH-1188', name: 'หูฟังบลูทูธ TWS', wh: 'CNX-02', available: 18, reserved: 6, shopee: true, tiktok: true, lazada: true),
    const StockRow(sku: 'SKU-LZ-7701', name: 'หม้อทอดไร้น้ำมัน 4.5L', wh: 'BKK-01', available: 8, reserved: 0, shopee: false, tiktok: false, lazada: true),
    const StockRow(sku: 'SKU-TT-5510', name: 'ครีมบำรุงผิว 50ml', wh: 'BKK-01', available: 0, reserved: 0, shopee: false, tiktok: true, lazada: false),
    const StockRow(sku: 'SKU-SH-2210', name: 'รองเท้าผ้าใบ ไซซ์ 39', wh: 'HDY-03', available: 12, reserved: 3, shopee: true, tiktok: false, lazada: false),
  ];

  static final shops = <ShopConn>[
    ShopConn(
      channel: Channel.shopee,
      status: ConnStatus.waiting,
      lastSync: DateTime(2024, 5, 5, 10, 12),
      mode: 'Sandbox',
      shop: 'PASS Official Shop',
      partnerId: 'SHP-882910',
    ),
    ShopConn(
      channel: Channel.tiktok,
      status: ConnStatus.sandbox,
      lastSync: DateTime(2024, 5, 5, 14, 40),
      mode: 'Sandbox',
      shop: 'PASS TikTok Shop',
      partnerId: 'TTS-104422',
    ),
    const ShopConn(
      channel: Channel.lazada,
      status: ConnStatus.off,
      lastSync: null,
      mode: '-',
      shop: '-',
      partnerId: '-',
    ),
  ];

  static final logs = <SyncRow>[
    SyncRow(time: DateTime(2024, 5, 5, 14, 41), channel: Channel.tiktok, orderNo: 'TT-240505-0001', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docNo: 'SO-240505-0141'),
    SyncRow(time: DateTime(2024, 5, 5, 11, 20), channel: Channel.shopee, orderNo: 'SHO-240505-0001', action: 'Validate Order', status: SyncStatus.pending, msg: 'รอตรวจสอบสต็อกคลัง BKK-01'),
    SyncRow(time: DateTime(2024, 5, 4, 19, 08), channel: Channel.shopee, orderNo: 'SHO-240504-0018', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docNo: 'SO-240504-0918'),
    SyncRow(time: DateTime(2024, 5, 4, 16, 44), channel: Channel.tiktok, orderNo: 'TT-240504-0007', action: 'Cancel in ERP', status: SyncStatus.error, msg: 'ไม่พบเอกสารต้นทางใน SAP'),
    SyncRow(time: DateTime(2024, 5, 3, 9, 15), channel: Channel.lazada, orderNo: 'LAZ-240503-0003', action: 'Pull Order', status: SyncStatus.error, msg: 'ยังไม่ได้เชื่อมต่อ API'),
    SyncRow(time: DateTime(2024, 5, 3, 8, 31), channel: Channel.shopee, orderNo: 'SHO-240503-0009', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docNo: 'SO-240503-0831'),
    SyncRow(time: DateTime(2024, 5, 2, 21, 06), channel: Channel.tiktok, orderNo: 'TT-240502-0012', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docNo: 'SO-240502-2106'),
  ];

  static Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }
}
