import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';

class ProductVariant {
  const ProductVariant({
    required this.sku,
    required this.modelId,
    required this.option,
    required this.price,
    required this.stock,
    required this.status,
    this.sapItemCode = '',
    this.imageUrl = '',
  });

  factory ProductVariant.fromApi(Map<String, dynamic> m) {
    final st = pickStr(m, ['Status', 'status', 'ProductStatus'], or: '').toLowerCase();
    final sap = pickStr(m, ['SapItemCode', 'sapItemCode', 'ItemCode', 'itemCode', 'ErpItemCode', 'erpItemCode'], or: '');
    return ProductVariant(
      sku: pickStr(m, ['Sku', 'sku', 'MarketplaceSku', 'variation_sku', 'SellerSku', 'sellerSku', 'model_sku', 'seller_sku']),
      modelId: pickStr(m, ['ModelId', 'modelId', 'model_id', 'VariationId', 'variationId', 'SkuId', 'skuId', 'model_sku_id'], or: ''),
      option: pickStr(m, ['Option', 'option', 'Name', 'name', 'Variation', 'variation', 'VariantName', 'spec', 'model_name', 'tier_index'], or: ''),
      price: pickDouble(m, ['Price', 'price', 'Amount']),
      stock: pickInt(m, ['Stock', 'stock', 'Quantity', 'Qty']),
      status: st.contains('inactive') || st.contains('off')
          ? ProductStatus.inactive
          : st.contains('draft')
              ? ProductStatus.draft
              : ProductStatus.active,
      sapItemCode: sap == '-' ? '' : sap,
      imageUrl: pickStr(m, ['Image', 'image', 'ImageUrl', 'imageUrl', 'image_url'], or: ''),
    );
  }

  final String sku;
  final String modelId;
  final String option;
  final double price;
  final int stock;
  final ProductStatus status;
  final String sapItemCode;
  final String imageUrl;

  bool get mapped => sapItemCode.isNotEmpty && sapItemCode != '-';
}

class Product {
  const Product({
    required this.sku,
    required this.name,
    required this.channel,
    required this.price,
    required this.stock,
    required this.status,
    required this.synced,
    this.productId = '',
    this.imageUrl = '',
    this.sapItemCode = '',
    this.variants = const [],
    this.updatedAt,
  });

  factory Product.fromApi(Map<String, dynamic> m) {
    final st = pickStr(m, ['Status', 'status', 'ProductStatus'], or: '').toLowerCase();
    final sap = pickStr(m, ['SapItemCode', 'sapItemCode', 'ItemCode', 'itemCode', 'ErpItemCode', 'erpItemCode'], or: '');
    final nested = pickList(m, [
      'Variants',
      'variants',
      'Variations',
      'variations',
      'Skus',
      'skus',
      'Models',
      'models',
      'model_list',
      'sku_list',
      'variation_list',
      'Items',
      'items',
    ]);
    final variants = [
      for (final row in nested)
        if (row is Map) ProductVariant.fromApi(Map<String, dynamic>.from(row)),
    ];
    return Product(
      sku: pickStr(m, ['Sku', 'sku', 'MarketplaceSku', 'ItemId', 'item_id'], or: '-'),
      productId: pickStr(m, ['ProductId', 'productId', 'ItemId', 'item_id', 'ParentId', 'parentId'], or: ''),
      name: pickStr(m, ['Name', 'name', 'ProductName', 'item_name'], or: '-'),
      channel: ChannelX.fromApi(pickStr(m, ['Platform', 'platform'], or: '')) ?? Channel.shopee,
      price: pickDouble(m, ['Price', 'price', 'Amount', 'MinPrice', 'minPrice']),
      stock: pickInt(m, ['Stock', 'stock', 'Quantity', 'TotalStock', 'totalStock']),
      status: st.contains('inactive') || st.contains('off')
          ? ProductStatus.inactive
          : st.contains('draft')
              ? ProductStatus.draft
              : ProductStatus.active,
      synced: pickStr(m, ['Synced', 'synced', 'SyncStatus'], or: '').toLowerCase().contains('sync') ||
          pick(m, ['Synced', 'synced']) == true,
      imageUrl: pickStr(m, ['Image', 'image', 'ImageUrl', 'imageUrl', 'image_url', 'Cover', 'cover'], or: ''),
      sapItemCode: sap == '-' ? '' : sap,
      variants: variants,
      updatedAt: pickTime(m, [
        'UpdatedAt',
        'updatedAt',
        'UpdateTime',
        'update_time',
        'SyncedAt',
        'syncedAt',
        'CreatedAt',
        'createdAt',
        'CreateTime',
        'create_time',
      ]),
    );
  }

  static List<Product> fromApiList(List<dynamic> rows) {
    final maps = [for (final row in rows) if (row is Map) Map<String, dynamic>.from(row)];
    final nested = <Product>[];
    final flat = <Map<String, dynamic>>[];
    for (final m in maps) {
      final hasNested = pickList(m, ['Variants', 'variants', 'Variations', 'variations', 'Skus', 'skus', 'Models', 'models', 'model_list', 'sku_list', 'variation_list']).isNotEmpty;
      if (hasNested) {
        nested.add(Product.fromApi(m));
      } else {
        flat.add(m);
      }
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < flat.length; i++) {
      final m = flat[i];
      var key = pickStr(m, ['ProductId', 'productId', 'ParentId', 'parentId', 'ItemId', 'item_id'], or: '');
      if (key.isEmpty || key == '-') key = '__solo_$i';
      groups.putIfAbsent(key, () => []).add(m);
    }
    final grouped = <Product>[];
    for (final e in groups.entries) {
      if (e.value.length == 1) {
        grouped.add(Product.fromApi(e.value.first));
      } else {
        grouped.add(Product.fromApi({
          ...e.value.first,
          'variants': e.value,
        }));
      }
    }
    return [...nested, ...grouped];
  }

  final String sku;
  final String productId;
  final String name;
  final Channel channel;
  final double price;
  final int stock;
  final ProductStatus status;
  final bool synced;
  final String imageUrl;
  final String sapItemCode;
  final List<ProductVariant> variants;
  final DateTime? updatedAt;

  bool get hasVariants => variants.isNotEmpty;
  int get variantCount => variants.length;
  int get stockTotal => hasVariants ? variants.fold(0, (a, v) => a + v.stock) : stock;
  double get priceFrom {
    if (!hasVariants) return price;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  String get displayId {
    final id = productId.isEmpty || productId == '-' ? sku : productId;
    return id;
  }

  String get parentSap {
    if (sapItemCode.isNotEmpty) return sapItemCode;
    if (!hasVariants) return '';
    final codes = {for (final v in variants) if (v.mapped) v.sapItemCode};
    if (codes.length == 1) return codes.first;
    if (codes.isEmpty) return '';
    return 'บางส่วน';
  }

  bool get mapped {
    if (parentSap.isNotEmpty && parentSap != 'บางส่วน') return true;
    if (!hasVariants) return sapItemCode.isNotEmpty;
    return variants.every((v) => v.mapped);
  }
}
