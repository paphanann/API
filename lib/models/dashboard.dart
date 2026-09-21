import '../core/json_util.dart';
import 'channel.dart';
import 'enums.dart';
import 'order.dart';
import 'shop.dart';

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
    );
  }

  factory DashData.fromLive({required List<Order> orders, required List<ShopConn> shops}) {
    final today = DateTime.now();
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
    );
  }
}
