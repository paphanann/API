import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'config.dart';
import 'json_util.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class Api {
  static String? token;

  static Uri _u(String path, [Map<String, String>? query]) {
    return Uri.parse('$apiUrl$path').replace(queryParameters: query);
  }

  static Map<String, String> _headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _send(Future<http.Response> req) async {
    try {
      return await req;
    } catch (_) {
      throw ApiException(
        'เชื่อมต่อ Backend ไม่ได้ ที่ $apiUrl — เปิด Express พอร์ต 3000 ก่อน และ CORS ต้องอนุญาต http://localhost:5173',
      );
    }
  }

  static String _backendMessage(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        for (final key in ['message', 'Message', 'error', 'Error', 'detail', 'Detail']) {
          final v = decoded[key];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
        }
      }
    } catch (_) {}
    return 'Backend ตอบ ${res.statusCode}';
  }

  static Future<dynamic> _json(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_backendMessage(res), statusCode: res.statusCode);
    }
    if (res.body.isEmpty) return Future.value(null);
    try {
      return Future.value(jsonDecode(res.body));
    } catch (_) {
      return Future.value(null);
    }
  }

  static List<dynamic> _list(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      for (final key in ['data', 'connections', 'orders', 'logs', 'items', 'result', 'products', 'inventory', 'stocks', 'warehouses', 'rows', 'value', 'list', 'users', 'accounts']) {
        final v = json[key];
        if (v is List) return v;
        if (v is Map) {
          for (final innerKey in ['data', 'items', 'products', 'rows', 'list', 'result']) {
            final inner = v[innerKey];
            if (inner is List) return inner;
          }
        }
      }
    }
    return const [];
  }

  static Future<void> checkHealth() async {
    final res = await _send(http.get(_u('/api/health'), headers: _headers()));
    await _json(res);
  }

  static Future<List<SyncRow>> getSyncLogs() async {
    final res = await _send(http.get(_u('/api/sync/logs'), headers: _headers()));
    final rows = _list(await _json(res));
    return [for (final row in rows) if (row is Map) SyncRow.fromApi(Map<String, dynamic>.from(row))];
  }

  static Future<DashData> getDashboard() async {
    final res = await _send(http.get(_u('/api/dashboard'), headers: _headers()));
    if (res.statusCode == 404) return DashData.empty();
    final data = await _json(res);
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = pick(map, ['data', 'Data', 'result', 'Result', 'dashboard', 'Dashboard']);
      if (nested is Map) return DashData.fromApi(Map<String, dynamic>.from(nested));
      return DashData.fromApi(map);
    }
    return DashData.empty();
  }

  static Future<DashData> dashboardFromLive() async {
    final chunks = await Future.wait([
      getOrders(platform: Channel.shopee.apiPlatform),
      getOrders(platform: Channel.tiktok.apiPlatform),
      getOrders(platform: Channel.lazada.apiPlatform),
      getConnections(),
    ]);
    return DashData.fromLive(
      orders: [
        ...chunks[0] as List<Order>,
        ...chunks[1] as List<Order>,
        ...chunks[2] as List<Order>,
      ],
      shops: chunks[3] as List<ShopConn>,
    );
  }

  static Future<List<StockRow>> getInventory({String? warehouse, String? platform}) async {
    final query = <String, String>{};
    if (warehouse != null && warehouse.isNotEmpty) query['warehouse'] = warehouse;
    if (platform != null && platform.isNotEmpty) query['platform'] = platform;
    final q = query.isEmpty ? null : query;

    var res = await _send(http.get(_u('/api/warehouses', q), headers: _headers()));
    if (res.statusCode == 404) {
      res = await _send(http.get(_u('/api/inventory', q), headers: _headers()));
    }
    if (res.statusCode == 404) {
      res = await _send(http.get(_u('/api/stocks', q), headers: _headers()));
    }
    final rows = _list(await _json(res));
    return [for (final row in rows) if (row is Map) StockRow.fromApi(Map<String, dynamic>.from(row))];
  }

  static Future<List<Product>> getProducts({String? platform}) async {
    final query = platform == null || platform.isEmpty ? null : {'platform': platform};
    final res = await _send(http.get(_u('/api/products', query), headers: _headers()));
    final rows = _list(await _json(res));
    return Product.fromApiList(rows);
  }

  static Future<AppSettings> getSettings() async {
    final res = await _send(http.get(_u('/api/settings'), headers: _headers()));
    final data = await _json(res);
    if (data is Map) return AppSettings.fromApi(Map<String, dynamic>.from(data));
    return AppSettings.blank();
  }

  static Future<void> saveSettings(AppSettings settings, {String? password}) async {
    final res = await _send(http.put(
      _u('/api/settings'),
      headers: _headers(json: true),
      body: jsonEncode(settings.toJson(password: password)),
    ));
    await _json(res);
  }

  static Future<ErpOptions> getErpOptions() async {
    final res = await _send(http.get(_u('/api/settings/erp-options'), headers: _headers()));
    if (res.statusCode == 404) return const ErpOptions();
    final data = await _json(res);
    if (data is Map) return ErpOptions.fromApi(Map<String, dynamic>.from(data));
    return const ErpOptions();
  }

  static Future<String> testErp(AppSettings settings, {String? password}) async {
    final res = await _send(http.post(
      _u('/api/settings/test-erp'),
      headers: _headers(json: true),
      body: jsonEncode(settings.toJson(password: password)),
    ));
    final data = await _json(res);
    if (data is Map) {
      return pickStr(Map<String, dynamic>.from(data), ['message', 'Message'], or: 'เชื่อมต่อสำเร็จ');
    }
    return 'เชื่อมต่อสำเร็จ';
  }

  static Future<List<StaffUser>> getUsers() async {
    for (final path in ['/api/users', '/api/settings/users']) {
      try {
        final res = await _send(http.get(_u(path), headers: _headers()));
        if (res.statusCode == 404) continue;
        final rows = _list(await _json(res));
        return [for (final row in rows) if (row is Map) StaffUser.fromApi(Map<String, dynamic>.from(row))];
      } on ApiException catch (e) {
        if (e.statusCode == 404) continue;
        rethrow;
      }
    }
    return [];
  }

  static Future<StaffUser> saveUser(StaffUser user, {String? password}) async {
    final creating = user.id.isEmpty || user.id == '-';
    final body = jsonEncode(user.toJson(password: password));
    ApiException? last;
    for (final base in ['/api/users', '/api/settings/users']) {
      try {
        final uri = creating ? _u(base) : _u('$base/${Uri.encodeComponent(user.apiKey)}');
        final res = await _send(
          creating
              ? http.post(uri, headers: _headers(json: true), body: body)
              : http.put(uri, headers: _headers(json: true), body: body),
        );
        if (res.statusCode == 404) continue;
        final data = await _json(res);
        if (data is Map) return StaffUser.fromApi(Map<String, dynamic>.from(data));
        return user;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          last = e;
          continue;
        }
        rethrow;
      }
    }
    throw last ?? ApiException('ไม่สามารถบันทึกผู้ใช้งานได้');
  }

  static Future<void> deleteUser(StaffUser user) async {
    ApiException? last;
    for (final base in ['/api/users', '/api/settings/users']) {
      try {
        final res = await _send(http.delete(_u('$base/${Uri.encodeComponent(user.apiKey)}'), headers: _headers()));
        if (res.statusCode == 404) continue;
        await _json(res);
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          last = e;
          continue;
        }
        rethrow;
      }
    }
    throw last ?? ApiException('ไม่สามารถลบผู้ใช้งานได้');
  }

  static Future<List<ShopConn>> getConnections() async {
    final res = await _send(http.get(_u('/api/connections'), headers: _headers()));
    final rows = _list(await _json(res));
    return [for (final row in rows) if (row is Map) ShopConn.fromApi(Map<String, dynamic>.from(row))];
  }

  static Future<List<Order>> getOrders({String? platform}) async {
    final query = platform == null || platform.isEmpty ? null : {'platform': platform};
    final res = await _send(http.get(_u('/api/orders', query), headers: _headers()));
    final rows = _list(await _json(res));
    return [for (final row in rows) if (row is Map) Order.fromApi(Map<String, dynamic>.from(row))];
  }

  static Future<void> syncPlatform(Channel channel) async {
    final res = await _send(http.post(_u('/api/sync/${channel.apiSlug}'), headers: _headers(json: true)));
    await _json(res);
  }

  static Future<Map<String, dynamic>> syncNow({bool force = false}) async {
    final res = await _send(
      http.post(
        _u('/api/sync/now', force ? {'force': '1'} : {'incremental': '1'}),
        headers: _headers(json: true),
        body: force ? '{}' : '{"incremental":true}',
      ),
    );
    final data = await _json(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': true};
  }

  /// ต้องใช้ location.href ไม่ใช่ fetch — Shopee จะพาไป Authorize แล้วเด้งกลับ Backend
  static const oauthReturnKey = 'pass_oauth_return';

  static bool get pendingOAuthReturn {
    final v = web.window.localStorage.getItem(oauthReturnKey);
    return v != null && v.isNotEmpty;
  }

  static void clearOAuthReturn() {
    web.window.localStorage.removeItem(oauthReturnKey);
  }

  static void connectPlatform(Channel channel) {
    final origin = web.window.location.origin;
    final back = '$origin/connections';
    web.window.localStorage.setItem(oauthReturnKey, channel.apiSlug);
    web.window.location.href = Uri.parse('$apiUrl/api/connections/${channel.apiSlug}/connect').replace(
      queryParameters: {'returnUrl': back, 'redirect': back},
    ).toString();
  }

  static Future<String> disconnectPlatform(Channel channel) async {
    final res = await _send(http.post(
      _u('/api/connections/${channel.apiSlug}/disconnect'),
      headers: _headers(json: true),
      body: '{}',
    ));
    final data = await _json(res);
    if (data is Map) {
      final msg = pickStr(Map<String, dynamic>.from(data), ['message', 'Message'], or: '');
      if (msg.isNotEmpty && msg != '-') return msg;
    }
    return 'ยกเลิกการเชื่อมต่อ ${channel.label} แล้ว';
  }

  /// ตรวจผู้ใช้จากฐานข้อมูลผ่าน Backend เท่านั้น
  static Future<AuthUser> login({required String email, required String password}) async {
    final body = jsonEncode({
      'email': email,
      'username': email,
      'password': password,
    });
    var res = await _send(http.post(_u('/api/auth/login'), headers: _headers(json: true), body: body));
    if (res.statusCode == 404) {
      res = await _send(http.post(_u('/api/login'), headers: _headers(json: true), body: body));
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      final msg = _backendMessage(res);
      throw ApiException(
        msg.startsWith('Backend ตอบ') ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' : msg,
        statusCode: res.statusCode,
      );
    }
    final data = await _json(res);
    if (data is! Map) {
      throw ApiException('รูปแบบข้อมูลล็อกอินไม่ถูกต้อง');
    }
    final map = Map<String, dynamic>.from(data);
    final nested = pick(map, ['user', 'User', 'data', 'Data']);
    final user = nested is Map ? Map<String, dynamic>.from(nested) : map;
    var name = pickStr(user, ['Name', 'name', 'FullName', 'DisplayName', 'displayName'], or: '');
    if (name == '-') name = '';
    return AuthUser(
      email: pickStr(user, ['Email', 'email', 'Username', 'username'], or: email),
      name: name,
      token: pickStr(map, ['Token', 'token', 'accessToken', 'access_token', 'jwt'], or: ''),
    );
  }
}
