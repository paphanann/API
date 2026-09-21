import '../core/json_util.dart';
import 'channel.dart';

class StockRow {
  const StockRow({
    this.channel,
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
  final String warehouseName;
  final String warehouseId;
  final String sapWhsCode;
  final int stock;
  final bool isDefault;
  final String status;
  final DateTime? updatedAt;
}
