import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';
import 'order.dart';
import 'shop.dart';

List<Order> _recentOrders(Map<String, dynamic> m) {
  final raw = pick(m, ['recent', 'Recent', 'orders', 'Orders']);
  if (raw is! List) return const [];
  return [
    for (final row in raw)
      if (row is Map) Order.fromApi(Map<String, dynamic>.from(row), listOnly: true),
  ];
}

class DashData {
  const DashData({
    required this.totalOrders,
    required this.pendingOrders,
    required this.successOrders,
    required this.connected,
    required this.weekLabels,
    required this.shopeeWeek,
    required this.tiktokWeek,
    required this.lazadaWeek,
    required this.shopeeShare,
    required this.tiktokShare,
    required this.lazadaShare,
    this.productCount = 0,
    this.soCount = 0,
    this.deliveryCount = 0,
    this.waitSo = 0,
    this.transferCount = 0,
    this.recent = const [],
  });

  factory DashData.empty() => const DashData(
        totalOrders: 0,
        pendingOrders: 0,
        successOrders: 0,
        connected: 0,
        weekLabels: [],
        shopeeWeek: [],
        tiktokWeek: [],
        lazadaWeek: [],
        shopeeShare: 0,
        tiktokShare: 0,
        lazadaShare: 0,
      );

  factory DashData.fromApi(Map<String, dynamic> m) {
    List<double> nums(List<String> keys) {
      final v = pick(m, keys);
      if (v is! List) return const [];
      return [
        for (final x in v) x is num ? x.toDouble() : double.tryParse('$x') ?? 0,
      ];
    }

    List<String> labels() {
      final v = pick(m, ['weekLabels', 'WeekLabels', 'labels', 'Labels']);
      if (v is! List) return const [];
      return [for (final x in v) '$x'];
    }

    return DashData(
      totalOrders: pickInt(m, ['totalOrders', 'TotalOrders', 'OrderCount', 'orderCount']),
      pendingOrders: pickInt(m, ['pendingOrders', 'PendingOrders', 'Pending']),
      successOrders: pickInt(m, ['successOrders', 'SuccessOrders', 'Success']),
      connected: pickInt(m, ['connected', 'Connected', 'ConnectedShops', 'connectedShops']),
      weekLabels: labels(),
      shopeeWeek: nums(['shopeeWeek', 'ShopeeWeek']),
      tiktokWeek: nums(['tiktokWeek', 'TiktokWeek', 'TikTokWeek']),
      lazadaWeek: nums(['lazadaWeek', 'LazadaWeek']),
      shopeeShare: pickDouble(m, ['shopeeShare', 'ShopeeShare']),
      tiktokShare: pickDouble(m, ['tiktokShare', 'TiktokShare', 'TikTokShare']),
      lazadaShare: pickDouble(m, ['lazadaShare', 'LazadaShare']),
      productCount: pickInt(m, ['productCount', 'ProductCount']),
      soCount: pickInt(m, ['soCount', 'SoCount']),
      deliveryCount: pickInt(m, ['deliveryCount', 'DeliveryCount']),
      waitSo: pickInt(m, ['waitSo', 'WaitSo']),
      transferCount: pickInt(m, ['transferCount', 'TransferCount', 'trCount', 'TrCount']),
      recent: _recentOrders(m),
    );
  }

  factory DashData.fromLive({required List<Order> orders, required List<ShopConn> shops, DateTime? until}) {
    final today = until ?? DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
    ];
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    List<double> week(Channel c) => [
          for (final day in days) orders.where((o) => o.channel == c && sameDay(o.createdAt, day)).length.toDouble(),
        ];
    final total = orders.length;
    double share(Channel c) => total == 0 ? 0 : orders.where((o) => o.channel == c).length * 100 / total;
    return DashData(
      totalOrders: orders.length,
      pendingOrders: orders.where((o) => o.status == OrderStatus.pending).length,
      successOrders: orders.where((o) => o.status == OrderStatus.success).length,
      connected: shops.where((s) => s.connected).length,
      weekLabels: [for (final d in days) '${d.day}/${d.month}'],
      shopeeWeek: week(Channel.shopee),
      tiktokWeek: week(Channel.tiktok),
      lazadaWeek: week(Channel.lazada),
      shopeeShare: share(Channel.shopee),
      tiktokShare: share(Channel.tiktok),
      lazadaShare: share(Channel.lazada),
      productCount: 0,
      soCount: orders.where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.returned && (o.sapDocNum ?? '').trim().isNotEmpty).length,
      deliveryCount: orders.where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.returned && o.hasDeliveryDoc).length,
      waitSo: orders.where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.returned && (o.sapDocNum ?? '').trim().isEmpty).length,
      transferCount: orders.where((o) => o.transferDocNum.trim().isNotEmpty).length,
    );
  }

  final int totalOrders;
  final int pendingOrders;
  final int successOrders;
  final int connected;
  final List<String> weekLabels;
  final List<double> shopeeWeek;
  final List<double> tiktokWeek;
  final List<double> lazadaWeek;
  final double shopeeShare;
  final double tiktokShare;
  final double lazadaShare;
  final int productCount;
  final int soCount;
  final int deliveryCount;
  final int waitSo;
  final int transferCount;
  final List<Order> recent;

  bool get hasStats => totalOrders > 0 || pendingOrders > 0 || successOrders > 0 || connected > 0;
  bool get hasCharts => shopeeWeek.isNotEmpty || tiktokWeek.isNotEmpty || lazadaWeek.isNotEmpty;

  DashData merge(DashData live) {
    return DashData(
      totalOrders: hasStats ? totalOrders : live.totalOrders,
      pendingOrders: hasStats ? pendingOrders : live.pendingOrders,
      successOrders: hasStats ? successOrders : live.successOrders,
      connected: hasStats ? connected : live.connected,
      weekLabels: weekLabels.isNotEmpty ? weekLabels : live.weekLabels,
      shopeeWeek: shopeeWeek.isNotEmpty ? shopeeWeek : live.shopeeWeek,
      tiktokWeek: tiktokWeek.isNotEmpty ? tiktokWeek : live.tiktokWeek,
      lazadaWeek: lazadaWeek.isNotEmpty ? lazadaWeek : live.lazadaWeek,
      shopeeShare: shopeeShare > 0 ? shopeeShare : live.shopeeShare,
      tiktokShare: tiktokShare > 0 ? tiktokShare : live.tiktokShare,
      lazadaShare: lazadaShare > 0 ? lazadaShare : live.lazadaShare,
      productCount: productCount > 0 ? productCount : live.productCount,
      soCount: soCount > 0 ? soCount : live.soCount,
      deliveryCount: deliveryCount > 0 ? deliveryCount : live.deliveryCount,
      waitSo: waitSo > 0 ? waitSo : live.waitSo,
      transferCount: transferCount > 0 ? transferCount : live.transferCount,
      recent: recent.isNotEmpty ? recent : live.recent,
    );
  }
}
