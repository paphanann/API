import 'dart:convert';

import 'package:web/web.dart' as web;

import '../core/api.dart';
import '../models/models.dart';
import 'pass_store.dart';
import 'shop_store.dart';

class InventoryStore extends PassStore {
  InventoryStore._();
  static final instance = InventoryStore._();

  List<StockRow> rows = [];
  bool loading = false;
  bool saving = false;
  String? error;

  Future<void> load({String? warehouse, String? platform}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (ShopStore.instance.realShops.isEmpty) {
        await ShopStore.instance.load();
      }
      var next = await Api.getInventory(warehouse: warehouse, platform: platform);
      next = _enrich(next);
      if (next.isEmpty) next = _fromShops();
      rows = [for (final r in next) r.copyWith(sapWhsCode: _mappedCode(r))];
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
      rows = _fromShops().map((r) => r.copyWith(sapWhsCode: _mappedCode(r))).toList();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> mapSap(StockRow row, String code) async {
    rows = [for (final r in rows) r.key == row.key ? r.copyWith(sapWhsCode: code) : r];
    _writeMap(row.key, code);
    final shop = _shopOf(row);
    if (shop != null) {
      final full = ShopStore.instance.withMeta(shop);
      ShopStore.instance.saveMeta(
        full,
        country: full.country,
        group: full.group,
        warehouse: code,
        note: full.note,
      );
    }
    notifyListeners();
    saving = true;
    notifyListeners();
    try {
      await Api.saveWarehouseMap(
        sapWhsCode: code,
        platform: row.channel?.apiPlatform,
        shopId: row.shopId.isNotEmpty && row.shopId != '-' ? row.shopId : shop?.shopId,
        warehouseId: row.warehouseId,
      );
    } on ApiException catch (e) {
      if (e.statusCode != 404) error = e.message;
    } catch (e) {
      error = e.toString();
    }
    saving = false;
    notifyListeners();
  }

  List<StockRow> _enrich(List<StockRow> src) {
    return [
      for (final r in src)
        r.copyWith(
          shopName: r.shopName.isNotEmpty && r.shopName != '-' ? r.shopName : (_shopOf(r)?.displayName ?? r.shopName),
          shopId: r.shopId.isNotEmpty && r.shopId != '-' ? r.shopId : (_shopOf(r)?.shopId ?? r.shopId),
        ),
    ];
  }

  List<StockRow> _fromShops() {
    return [
      for (final s in ShopStore.instance.realShops)
        StockRow(
          channel: s.channel,
          shopName: s.displayName,
          shopId: s.shopId,
          warehouseName: 'MARKETPLACE',
          warehouseId: s.shopId == '-' ? '' : s.shopId,
          sapWhsCode: ShopStore.instance.withMeta(s).warehouse,
          stock: 0,
          isDefault: false,
          status: s.connected ? 'connected' : 'off',
          updatedAt: s.lastSync,
        ),
    ];
  }

  ShopConn? _shopOf(StockRow r) {
    final shops = ShopStore.instance.realShops;
    for (final s in shops) {
      if (r.channel != null && s.channel != r.channel) continue;
      if (r.shopId.isNotEmpty && r.shopId != '-' && (s.shopId == r.shopId || s.shop == r.shopId)) return s;
      if (r.shopName.isNotEmpty && r.shopName != '-' && s.displayName.toLowerCase() == r.shopName.toLowerCase()) return s;
    }
    if (r.channel != null) {
      final same = [for (final s in shops) if (s.channel == r.channel) s];
      if (same.length == 1) return same.first;
    }
    return null;
  }

  String _mappedCode(StockRow r) {
    final saved = web.window.localStorage.getItem(_mapKey(r.key));
    if (saved != null && saved.isNotEmpty) return saved;
    if (r.sapWhsCode.isNotEmpty && r.sapWhsCode != '-') return r.sapWhsCode;
    return _shopOf(r)?.warehouse ?? '';
  }

  void _writeMap(String key, String code) {
    final store = web.window.localStorage;
    if (code.isEmpty) {
      store.removeItem(_mapKey(key));
    } else {
      store.setItem(_mapKey(key), code);
    }
    try {
      final raw = store.getItem('pass_wh_maps') ?? '{}';
      final map = jsonDecode(raw);
      if (map is Map) {
        final next = Map<String, dynamic>.from(map);
        if (code.isEmpty) {
          next.remove(key);
        } else {
          next[key] = code;
        }
        store.setItem('pass_wh_maps', jsonEncode(next));
      }
    } catch (_) {}
  }

  String _mapKey(String key) => 'pass_wh_map_$key';
}
