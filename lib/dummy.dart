import 'models.dart';

// ข้อมูลตัวอย่างทั้งก้อน เดี๋ยวค่อยย้ายไป API
//
// ออเดอร์:
// Shopee  = order_sn 14 ตัว (YYMMDD + 8 ตัวอักษร/ตัวเลข)
// TikTok  = order_id 18 หลัก ขึ้นต้น 57 หรือ 58
// Lazada  = order_id 15 หลัก ตัวเลขล้วน
//
// SKU สินค้า/คลัง:
// Shopee  = item_id 10 หลัก ตัวเลขล้วน
// TikTok  = sku_id / product_id ขึ้นต้นด้วย 17 (19 หลัก)
// การเชื่อมต่อ:
// Shopee  = shop_id 9 หลัก, partner_id 7 หลัก, token 32 ตัว hex
// TikTok  = shop_id / app_key 19 หลัก, token 48 ตัว hex
// Lazada  = ยังไม่เชื่อม แสดง -
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
      id: '576485029403847192',
      channel: Channel.tiktok,
      customer: 'สมชาย ใจดี',
      phone: '081-234-5678',
      address: '99/12 ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
      createdAt: DateTime(2024, 5, 5, 14, 32),
      status: OrderStatus.success,
      payment: 'TikTok Pay',
      shipping: 'Kerry Express',
      lines: const [
        OrderLine(sku: '1729382254395412481', name: 'เสื้อยืดคอกลม สีขาว', qty: 2, price: 259),
        OrderLine(sku: '1729382254395412498', name: 'กางเกงขาสั้น ผ้าฝ้าย', qty: 1, price: 390),
      ],
    ),
    Order(
      id: '2405058R48U37H',
      channel: Channel.shopee,
      customer: 'วิภาดา พูนสุข',
      phone: '089-551-2201',
      address: '18 หมู่ 4 ต.บางรัก อ.เมือง จ.สมุทรปราการ 10270',
      createdAt: DateTime(2024, 5, 5, 11, 18),
      status: OrderStatus.pending,
      payment: 'Shopee Pay',
      shipping: 'Shopee Express',
      lines: const [
        OrderLine(sku: '2847391026', name: 'กระเป๋าสะพายข้าง', qty: 1, price: 890),
      ],
    ),
    Order(
      id: '240504AV5TVWC2',
      channel: Channel.shopee,
      customer: 'กิตติพงศ์ แสงทอง',
      phone: '086-778-4410',
      address: '201 ถ.นิมมานเหมินท์ ต.สุเทพ อ.เมือง จ.เชียงใหม่ 50200',
      createdAt: DateTime(2024, 5, 4, 19, 5),
      status: OrderStatus.success,
      payment: 'บัตรเครดิต',
      shipping: 'Thai Post EMS',
      lines: const [
        OrderLine(sku: '1928473650', name: 'หูฟังบลูทูธ TWS', qty: 1, price: 1290),
        OrderLine(sku: '1928473702', name: 'เคสกันกระแทก', qty: 2, price: 159),
      ],
    ),
    Order(
      id: '582391847201938475',
      channel: Channel.tiktok,
      customer: 'นภา ศรีสุข',
      phone: '092-334-8890',
      address: '55/8 ถ.รัชดาภิเษก แขวงดินแดง เขตดินแดง กรุงเทพฯ 10400',
      createdAt: DateTime(2024, 5, 4, 16, 41),
      status: OrderStatus.cancelled,
      payment: 'COD',
      shipping: 'Flash Express',
      lines: const [
        OrderLine(sku: '1729481102837465910', name: 'ครีมบำรุงผิว 50ml', qty: 3, price: 320),
      ],
    ),
    Order(
      id: '414829384756102',
      channel: Channel.lazada,
      customer: 'อรุณ มาลี',
      phone: '083-990-1122',
      address: '12 ซอยลาดพร้าว 71 แขวงลาดพร้าว เขตลาดพร้าว กรุงเทพฯ 10230',
      createdAt: DateTime(2024, 5, 3, 9, 12),
      status: OrderStatus.pending,
      payment: 'Lazada Wallet',
      shipping: 'LEX',
      lines: const [
        OrderLine(sku: '3847561029_TH-11212296431', name: 'หม้อทอดไร้น้ำมัน 4.5L', qty: 1, price: 2490),
      ],
    ),
    Order(
      id: '240503N0JVTYN8',
      channel: Channel.shopee,
      customer: 'ปิยะนุช จันทร์เพ็ญ',
      phone: '061-445-7788',
      address: '88 ถ.เพชรเกษม ต.หาดใหญ่ อ.หาดใหญ่ จ.สงขลา 90110',
      createdAt: DateTime(2024, 5, 3, 8, 27),
      status: OrderStatus.success,
      payment: 'โอนธนาคาร',
      shipping: 'J&T Express',
      lines: const [
        OrderLine(sku: '3109284756', name: 'รองเท้าผ้าใบ ไซซ์ 39', qty: 1, price: 790),
        OrderLine(sku: '3109284811', name: 'ถุงเท้ากีฬา 3 คู่', qty: 1, price: 129),
      ],
    ),
    Order(
      id: '575928104736192847',
      channel: Channel.tiktok,
      customer: 'ธนพล วัฒนา',
      phone: '084-220-6677',
      address: '3/15 ถ.มิตรภาพ ต.ในเมือง อ.เมือง จ.ขอนแก่น 40000',
      createdAt: DateTime(2024, 5, 2, 21, 3),
      status: OrderStatus.success,
      payment: 'TikTok Pay',
      shipping: 'SPX Express',
      lines: const [
        OrderLine(sku: '1729510283746591820', name: 'แก้วเก็บความเย็น 20oz', qty: 2, price: 450),
      ],
    ),
    Order(
      id: '240501JYEEFW0K',
      channel: Channel.shopee,
      customer: 'มณีรัตน์ ทองดี',
      phone: '098-111-3344',
      address: '70 หมู่บ้านสวนสยาม เขตคันนายาว กรุงเทพฯ 10230',
      createdAt: DateTime(2024, 5, 1, 13, 55),
      status: OrderStatus.pending,
      payment: 'Shopee PayLater',
      shipping: 'Shopee Express',
      lines: const [
        OrderLine(sku: '4478120391', name: 'ชุดเครื่องนอน 6 ฟุต', qty: 1, price: 1590),
      ],
    ),
  ];

  static final products = <Product>[
    const Product(sku: '2847391026', name: 'กระเป๋าสะพายข้าง', channel: Channel.shopee, price: 890, stock: 42, status: ProductStatus.active, synced: true),
    const Product(sku: '1729382254395412481', name: 'เสื้อยืดคอกลม สีขาว', channel: Channel.tiktok, price: 259, stock: 180, status: ProductStatus.active, synced: true),
    const Product(sku: '1928473650', name: 'หูฟังบลูทูธ TWS', channel: Channel.shopee, price: 1290, stock: 24, status: ProductStatus.active, synced: true),
    const Product(sku: '3847561029_TH-11212296431', name: 'หม้อทอดไร้น้ำมัน 4.5L', channel: Channel.lazada, price: 2490, stock: 8, status: ProductStatus.active, synced: false),
    const Product(sku: '1729481102837465910', name: 'ครีมบำรุงผิว 50ml', channel: Channel.tiktok, price: 320, stock: 0, status: ProductStatus.inactive, synced: true),
    const Product(sku: '3109284756', name: 'รองเท้าผ้าใบ ไซซ์ 39', channel: Channel.shopee, price: 790, stock: 15, status: ProductStatus.active, synced: true),
    const Product(sku: '1729510283746591820', name: 'แก้วเก็บความเย็น 20oz', channel: Channel.tiktok, price: 450, stock: 67, status: ProductStatus.active, synced: true),
    const Product(sku: '4478120391', name: 'ชุดเครื่องนอน 6 ฟุต', channel: Channel.shopee, price: 1590, stock: 11, status: ProductStatus.draft, synced: false),
  ];

  static final stocks = <StockRow>[
    StockRow(sku: 'ITEM-000001', name: 'เสื้อยืดคอกลม สีขาว Size M', wh: '01', available: 160, reserved: 20, shopee: true, tiktok: true, lazada: false, updatedAt: DateTime(2024, 5, 7, 14, 32)),
    StockRow(sku: 'ITEM-000002', name: 'กางเกงขายาว ผ้าเวสปอย Size 32', wh: '01', available: 85, reserved: 10, shopee: true, tiktok: true, lazada: false, updatedAt: DateTime(2024, 5, 7, 14, 18)),
    StockRow(sku: 'ITEM-000003', name: 'รองเท้าผ้าใบ รุ่น A1 สีขาว', wh: '02', available: 45, reserved: 5, shopee: true, tiktok: false, lazada: true, updatedAt: DateTime(2024, 5, 7, 13, 55)),
    StockRow(sku: 'ITEM-000004', name: 'กระเป๋าสะพายข้าง', wh: '01', available: 38, reserved: 4, shopee: true, tiktok: false, lazada: false, updatedAt: DateTime(2024, 5, 7, 13, 40)),
    StockRow(sku: 'ITEM-000005', name: 'หูฟังบลูทูธ TWS', wh: '02', available: 24, reserved: 6, shopee: true, tiktok: true, lazada: true, updatedAt: DateTime(2024, 5, 7, 12, 10)),
    StockRow(sku: 'ITEM-000006', name: 'หม้อทอดไร้น้ำมัน 4.5L', wh: '01', available: 8, reserved: 0, shopee: false, tiktok: false, lazada: true, updatedAt: DateTime(2024, 5, 7, 11, 22)),
    StockRow(sku: 'ITEM-000007', name: 'ครีมบำรุงผิว 50ml', wh: '03', available: 0, reserved: 0, shopee: false, tiktok: true, lazada: false, updatedAt: DateTime(2024, 5, 7, 10, 5)),
    StockRow(sku: 'ITEM-000008', name: 'ชุดเครื่องนอน 6 ฟุต', wh: '03', available: 200, reserved: 5, shopee: true, tiktok: false, lazada: false, updatedAt: DateTime(2024, 5, 7, 9, 48)),
  ];

  static final shops = <ShopConn>[
    ShopConn(
      channel: Channel.shopee,
      status: ConnStatus.live,
      shop: 'PASS Official Shop',
      shopId: '122889934',
      partnerId: '2001887',
      mode: 'Production',
      accessToken: '6b5a46716e474d6f6e59777659459849',
      refreshToken: '4c7259534969484e71734d695a6e0d55',
      lastConnected: DateTime(2024, 5, 7, 9, 15, 22),
      lastSync: DateTime(2024, 5, 7, 9, 14, 58),
      health: 'ปกติ',
    ),
    ShopConn(
      channel: Channel.tiktok,
      status: ConnStatus.sandbox,
      shop: 'PASS TikTok Shop',
      shopId: '7494482173176529190',
      partnerId: '7494482173176529180',
      mode: 'Sandbox',
      accessToken: '7c2d91b047e65f18a4c90d3b27e61c5f8a14d2e90b7c39f0',
      refreshToken: '9e4f18c2d047b65a4e90d3b27e61c5f8a14d2e90b7c39a12',
      lastConnected: DateTime(2024, 5, 7, 9, 10, 33),
      lastSync: DateTime(2024, 5, 7, 9, 10, 12),
      health: 'ปกติ',
    ),
    const ShopConn(
      channel: Channel.lazada,
      status: ConnStatus.waiting,
      shop: '-',
      shopId: '-',
      partnerId: '-',
      mode: '-',
      accessToken: '-',
      refreshToken: '-',
      lastConnected: null,
      lastSync: null,
      health: '-',
    ),
  ];

  static final logs = <SyncRow>[
    SyncRow(time: DateTime(2024, 5, 5, 14, 41), channel: Channel.tiktok, orderNo: '576485029403847192', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docEntry: '18452', docNum: '24000152'),
    SyncRow(time: DateTime(2024, 5, 5, 11, 20), channel: Channel.shopee, orderNo: '2405058R48U37H', action: 'Validate Order', status: SyncStatus.pending, msg: 'รอตรวจสอบสต็อกคลัง BKK-01'),
    SyncRow(time: DateTime(2024, 5, 4, 19, 08), channel: Channel.shopee, orderNo: '240504AV5TVWC2', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docEntry: '18453', docNum: '24000153'),
    SyncRow(time: DateTime(2024, 5, 4, 16, 44), channel: Channel.tiktok, orderNo: '582391847201938475', action: 'Cancel in ERP', status: SyncStatus.error, msg: 'ไม่พบเอกสารต้นทางใน SAP'),
    SyncRow(time: DateTime(2024, 5, 3, 9, 15), channel: Channel.lazada, orderNo: '414829384756102', action: 'Pull Order', status: SyncStatus.error, msg: 'ยังไม่ได้เชื่อมต่อ API'),
    SyncRow(time: DateTime(2024, 5, 3, 8, 31), channel: Channel.shopee, orderNo: '240503N0JVTYN8', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docEntry: '18454', docNum: '24000154'),
    SyncRow(time: DateTime(2024, 5, 2, 21, 06), channel: Channel.tiktok, orderNo: '575928104736192847', action: 'Sync to ERP', status: SyncStatus.success, msg: 'สร้างเอกสารสำเร็จ', docEntry: '18455', docNum: '24000155'),
  ];

  static Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }
}
