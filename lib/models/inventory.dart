import '../core/json_util.dart';
import 'channel.dart';

class StockRow {
  const StockRow({
    this.channel,
    this.shopName = '',
    this.shopId = '',
    required this.warehouseName,
    required this.warehouseId,
    required this.sapWhsCode,
    required this.stock,
    required this.isDefault,
    required this.status,
    this.updatedAt,
  });

  factory StockRow.fromApi(Map<String, dynamic> m) {
    var channel = ChannelX.fromApi(pickStr(m, ['Platform', 'platform', 'Channel', 'channel'], or: ''));
    if (channel == null) {
      if (pickBool(m, ['Shopee', 'shopee', 'OnShopee']) == true) {
        channel = Channel.shopee;
      } else if (pickBool(m, ['TikTok', 'Tiktok', 'tiktok', 'OnTikTok']) == true) {
        channel = Channel.tiktok;
      } else if (pickBool(m, ['Lazada', 'lazada', 'OnLazada']) == true) {
        channel = Channel.lazada;
      }
    }

    return StockRow(
      channel: channel,
      shopName: pickPlainStr(m, ['ShopName', 'shopName', 'shop_name', 'SellerName', 'sellerName'], or: ''),
      shopId: pickPlainStr(m, ['ShopId', 'shopId', 'shop_id', 'SellerId', 'sellerId', 'seller_id'], or: ''),
      warehouseName: pickStr(m, [
        'WarehouseName',
        'warehouseName',
        'WhsName',
        'whsName',
        'Warehouse',
        'warehouse',
        'Name',
        'name',
      ]),
      warehouseId: pickStr(m, [
        'WarehouseId',
        'warehouseId',
        'WarehouseID',
        'LocationId',
        'locationId',
        'WhsId',
        'whsId',
      ]),
      sapWhsCode: pickStr(m, [
        'SapWhsCode',
        'sapWhsCode',
        'SAPWhsCode',
        'WhsCode',
        'whsCode',
        'SapWarehouse',
        'sapWarehouse',
      ]),
      stock: pickInt(m, ['Stock', 'stock', 'Available', 'available', 'OnHand', 'onHand', 'Quantity', 'Qty']),
      isDefault: pickBool(m, ['Default', 'default', 'IsDefault', 'isDefault', 'IsDefaultWarehouse']) == true,
      status: pickStr(m, ['Status', 'status', 'WarehouseStatus', 'warehouseStatus'], or: ''),
      updatedAt: pickTime(m, [
        'UpdatedAt',
        'updatedAt',
        'LastUpdated',
        'lastUpdated',
        'CreatedAt',
        'createdAt',
        'CreateTime',
      ]),
    );
  }

  final Channel? channel;
  final String shopName;
  final String shopId;
  final String warehouseName;
  final String warehouseId;
  final String sapWhsCode;
  final int stock;
  final bool isDefault;
  final String status;
  final DateTime? updatedAt;

  String get key => '${channel?.name ?? ''}|$shopId|$warehouseId|$warehouseName';

  StockRow copyWith({String? sapWhsCode, String? shopName, String? shopId}) {
    return StockRow(
      channel: channel,
      shopName: shopName ?? this.shopName,
      shopId: shopId ?? this.shopId,
      warehouseName: warehouseName,
      warehouseId: warehouseId,
      sapWhsCode: sapWhsCode ?? this.sapWhsCode,
      stock: stock,
      isDefault: isDefault,
      status: status,
      updatedAt: updatedAt,
    );
  }
}
