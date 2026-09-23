import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Listenable _listenable = Listenable.merge([
    DashStore.instance,
    ShopStore.instance,
    OrderStore.instance,
    ProductStore.instance,
    SyncLogStore.instance,
  ]);

  static const _thMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  DateTime? _from;
  DateTime? _to;
  int _month = 0;
  int _year = 0;
  String _ch = 'all';

  @override
  void initState() {
    super.initState();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _to = today;
    _from = today.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DashStore.instance.load();
      ShopStore.instance.load();
      OrderStore.instance.load();
      ProductStore.instance.load();
      SyncLogStore.instance.load();
    });
  }

  DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  bool _inFilter(DateTime t) {
    final day = _day(t);
    if (_from != null && day.isBefore(_from!)) return false;
    if (_to != null && day.isAfter(_to!)) return false;
    if (_month != 0 && t.month != _month) return false;
    if (_year != 0 && t.year != _year) return false;
    return true;
  }

  Future<void> _pickRange() async {
    final today = _day(DateTime.now());
    final picked = await showSimpleCalendar(
      context: context,
      from: _from ?? today.subtract(const Duration(days: 30)),
      to: _to ?? today,
    );
    if (picked == null) return;
    setState(() {
      if (picked.cleared) {
        _from = null;
        _to = null;
      } else {
        _from = _day(picked.range!.start);
        _to = _day(picked.range!.end);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        final dash = DashStore.instance;
        final shops = ShopStore.instance.shops;
        final scopedShops = _ch == 'all' ? shops : shops.where((s) => s.channel.name == _ch).toList();
        final orders = OrderStore.instance.orders.where((o) {
          if (_ch != 'all' && o.channel.name != _ch) return false;
          return _inFilter(o.createdAt);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final logs = SyncLogStore.instance.logs.where((l) {
          if (_ch != 'all' && l.channel.name != _ch) return false;
          return _inFilter(l.time);
        }).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        final d = DashData.fromLive(orders: orders, shops: scopedShops, until: _to);
        final connected = scopedShops.where((s) => s.connected).length;
        final shopTotal = _ch == 'all' ? Channel.values.length : 1;
        final orderHint = _weekHint(d);
        SyncRow? lastOkLog;
        for (final l in logs) {
          if (l.status == SyncStatus.success || l.status == SyncStatus.partial) {
            lastOkLog = l;
            break;
          }
        }
        final problemPlatforms = logs
            .where((l) => l.status == SyncStatus.error)
            .map((l) => l.channel)
            .toSet()
            .length;
        final years = {
          DateTime.now().year,
          DateTime.now().year - 1,
          DateTime.now().year - 2,
          for (final o in OrderStore.instance.orders) o.createdAt.year,
        }.toList()
          ..sort((a, b) => b.compareTo(a));

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final title = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('หน้าหลัก', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('ภาพรวมระบบเชื่อมต่อ Marketplace และ SAP', style: TextStyle(color: Pal.muted, fontSize: 13)),
                    ],
                  );
                  final filters = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      DateRangeField(from: _from, to: _to, onTap: _pickRange),
                      Drop<int>(
                        label: 'เดือน',
                        value: _month,
                        width: 150,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('ทั้งหมด')),
                          for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text(_thMonths[i - 1])),
                        ],
                        onChanged: (v) => setState(() => _month = v ?? 0),
                      ),
                      Drop<int>(
                        label: 'ปี',
                        value: _year,
                        width: 120,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('ทั้งหมด')),
                          for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) => setState(() => _year = v ?? 0),
                      ),
                      Drop<String>(
                        label: 'แพลตฟอร์ม',
                        value: _ch,
                        width: 160,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                          for (final c in Channel.values) DropdownMenuItem(value: c.name, child: Text(c.shortLabel)),
                        ],
                        onChanged: (v) => setState(() => _ch = v ?? 'all'),
                      ),
                    ],
                  );
                  if (box.maxWidth < 1100) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 14), filters],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(width: 16),
                      Expanded(child: filters),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              if (dash.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Pal.errBg,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(dash.error!, style: const TextStyle(color: Pal.err)),
                    ),
                  ),
                ),
              if (dash.loading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(minHeight: 3)),
              LayoutBuilder(
                builder: (context, c) {
                  final cards = [
                    StatCard(
                      title: 'คำสั่งซื้อทั้งหมด',
                      value: nFmt.format(d.totalOrders),
                      icon: Icons.shopping_cart_outlined,
                      color: const Color(0xFF2563EB),
                      hint: orderHint == null
                          ? null
                          : Text(orderHint, style: TextStyle(color: orderHint.startsWith('-') ? Pal.err : Pal.ok, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    StatCard(
                      title: 'Sync สำเร็จล่าสุด',
                      value: lastOkLog == null ? '—' : timeFmt.format(lastOkLog.time),
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF0D9488),
                      hint: Text(
                        lastOkLog == null ? 'ยังไม่มีประวัติ' : lastOkLog.channel.shortLabel,
                        style: TextStyle(color: lastOkLog == null ? Pal.muted : Pal.ok, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    StatCard(
                      title: 'มีปัญหาการซิงก์',
                      value: nFmt.format(problemPlatforms),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF97316),
                      hint: Text(
                        problemPlatforms > 0 ? 'แพลตฟอร์มที่ error' : 'ไม่มีปัญหา',
                        style: TextStyle(color: problemPlatforms > 0 ? Pal.warn : Pal.ok, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    StatCard(
                      title: 'เชื่อมต่อแล้ว',
                      value: '$connected/$shopTotal',
                      icon: Icons.power_outlined,
                      color: Pal.ok,
                      hint: Text(
                        connected == shopTotal && shopTotal > 0 ? 'ครบทุกแพลตฟอร์ม' : 'รอเชื่อมต่อ',
                        style: TextStyle(color: connected == shopTotal && shopTotal > 0 ? Pal.ok : Pal.warn, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ];
                  if (c.maxWidth >= 1100) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  }
                  final w = c.maxWidth >= 720 ? (c.maxWidth - 16) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final card in cards) SizedBox(width: w, child: card)],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  Widget trend({required bool expand}) => Panel(
                        expand: expand,
                        title: 'สรุปคำสั่งซื้อ 7 วันล่าสุด',
                        trailing: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Wrap(
                            spacing: 14,
                            children: [
                              _Dot(color: Pal.shopee, text: 'Shopee'),
                              _Dot(color: Pal.tiktok, text: 'TikTok Shop'),
                              _Dot(color: Pal.lazada, text: 'Lazada'),
                            ],
                          ),
                        ),
                        child: expand
                            ? SizedBox.expand(child: _Trend(d))
                            : SizedBox(width: double.infinity, height: 260, child: _Trend(d)),
                      );
                  Widget conns({required bool expand}) => Panel(
                        expand: expand,
                        title: 'สถานะการเชื่อมต่อ',
                        trailing: TextButton(
                          onPressed: () => context.go('/connections'),
                          child: const Text('จัดการการเชื่อมต่อ'),
                        ),
                        child: _ConnList(shops),
                      );
                  if (c.maxWidth < 960) {
                    return Column(children: [trend(expand: false), const SizedBox(height: 16), conns(expand: false)]);
                  }
                  return SizedBox(
                    height: 340,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: trend(expand: true)),
                        const SizedBox(width: 16),
                        Expanded(child: conns(expand: true)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final share = Panel(
                    title: 'สัดส่วนคำสั่งซื้อ',
                    child: SizedBox(height: 180, child: _Share(d)),
                  );
                  final recent = Panel(
                    title: 'คำสั่งซื้อล่าสุด',
                    trailing: TextButton(
                      onPressed: () => context.go('/orders'),
                      child: const Text('ดูทั้งหมด →'),
                    ),
                    pad: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _RecentOrders(orders.take(4).toList()),
                  );
                  final sync = Panel(
                    title: 'Sync Log ล่าสุด',
                    trailing: TextButton(
                      onPressed: () => context.go('/sync-log'),
                      child: const Text('ดูทั้งหมด →'),
                    ),
                    pad: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _RecentLogs(logs.take(5).toList()),
                  );
                  if (c.maxWidth < 1100) {
                    return Column(
                      children: [
                        share,
                        const SizedBox(height: 16),
                        recent,
                        const SizedBox(height: 16),
                        sync,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: share),
                        const SizedBox(width: 16),
                        Expanded(child: recent),
                        const SizedBox(width: 16),
                        Expanded(child: sync),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _weekHint(DashData d) {
  final n = [d.shopeeWeek.length, d.tiktokWeek.length, d.lazadaWeek.length].fold<int>(0, math.max);
  if (n < 6) return null;
  double at(List<double> s, int i) => i < s.length ? s[i] : 0;
  final days = [
    for (var i = 0; i < n; i++) at(d.shopeeWeek, i) + at(d.tiktokWeek, i) + at(d.lazadaWeek, i),
  ];
  final prev = days.take(3).fold<double>(0, (a, b) => a + b);
  final next = days.skip(n - 3).fold<double>(0, (a, b) => a + b);
  if (prev <= 0) return null;
  final pct = ((next - prev) / prev * 100).round();
  if (pct == 0) return 'ไม่เปลี่ยนแปลงจากช่วงก่อน';
  return pct > 0 ? '+$pct% จากช่วงก่อน' : '$pct% จากช่วงก่อน';
}

class _ConnList extends StatelessWidget {
  const _ConnList(this.shops);

  final List<ShopConn> shops;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final c in Channel.values)
        shops.where((s) => s.channel == c).followedBy([ShopConn.empty(c)]).first,
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _connRow(rows[i]),
        ],
      ],
    );
  }

  Widget _connRow(ShopConn s) {
    return Row(
      children: [
        ChannelDot(channel: s.channel, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(s.channel.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              s.connected ? 'เชื่อมต่อแล้ว' : (s.needsReauth ? 'ต้องเชื่อมต่อใหม่' : 'ยังไม่เชื่อมต่อ'),
              style: TextStyle(
                color: s.connected ? Pal.ok : Pal.err,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Last Sync: ${s.lastSync == null ? '-' : formatDt(s.lastSync)}',
              style: const TextStyle(color: Pal.muted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders(this.orders);

  final List<Order> orders;
  static const _flex = [3, 2, 2, 2, 2, 2];

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('ไม่พบคำสั่งซื้อ', style: TextStyle(color: Pal.muted))),
      );
    }
    return Column(
      children: [
        const _MiniHead(cells: ['เลขที่คำสั่งซื้อ', 'แพลตฟอร์ม', 'วันที่', 'ยอดรวม', 'สถานะออเดอร์', 'Sync'], flex: _flex),
        for (final o in orders)
          _MiniRow(
            flex: _flex,
            onTap: () => context.go('/orders/${Uri.encodeComponent(o.id)}'),
            cells: [
              Tooltip(
                message: o.id,
                child: Text(
                  o.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              Text(o.channel.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              Text(dayFmt.format(o.createdAt), maxLines: 1, style: const TextStyle(fontSize: 12, color: Pal.muted)),
              Text(baht.format(o.total), maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              _dotStatus(o.status == OrderStatus.success
                  ? (Pal.ok, 'สำเร็จ')
                  : o.status == OrderStatus.cancelled
                      ? (Pal.err, 'ยกเลิก')
                      : (Pal.warn, 'รอดำเนินการ')),
              _orderSync(o),
            ],
          ),
      ],
    );
  }

  Widget _orderSync(Order o) {
    final synced = o.sapDocNum != null && o.sapDocNum!.isNotEmpty;
    if (synced) return _dotStatus((Pal.ok, 'สำเร็จ'));
    if (o.status == OrderStatus.cancelled) {
      return const Text('—', style: TextStyle(color: Pal.muted, fontSize: 12));
    }
    return _dotStatus((Pal.warn, 'รอดำเนินการ'));
  }
}

class _RecentLogs extends StatelessWidget {
  const _RecentLogs(this.logs);

  final List<SyncRow> logs;
  static const _flex = [2, 2, 2, 3];

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('ไม่พบ Sync Log', style: TextStyle(color: Pal.muted))),
      );
    }
    return Column(
      children: [
        const _MiniHead(cells: ['เวลา', 'แพลตฟอร์ม', 'ผลการ Sync', 'รายละเอียด'], flex: _flex),
        for (final l in logs)
          _MiniRow(
            flex: _flex,
            onTap: () => context.go('/sync-log/${l.routeId}'),
            cells: [
              Text(timeFmt.format(l.time), maxLines: 1, style: const TextStyle(fontSize: 12, color: Pal.muted)),
              Text(l.channel.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              _dotStatus(l.status == SyncStatus.success
                  ? (Pal.ok, 'สำเร็จ')
                  : l.status == SyncStatus.error
                      ? (Pal.err, 'ล้มเหลว')
                      : l.status == SyncStatus.partial
                          ? (Pal.warn, 'สำเร็จบางส่วน')
                          : (const Color(0xFF1D4ED8), 'กำลังซิงก์')),
              Text(
                l.dashDetail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

Widget _dotStatus((Color, String) s) {
  return Row(
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: s.$1, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          s.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _MiniHead extends StatelessWidget {
  const _MiniHead({required this.cells, this.flex = const []});

  final List<String> cells;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i < flex.length ? flex[i] : 1,
              child: Text(cells[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Pal.muted, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.cells, this.onTap, this.flex = const []});

  final List<Widget> cells;
  final List<int> flex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: i < flex.length ? flex[i] : 1,
                child: Align(alignment: Alignment.centerLeft, child: cells[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend(this.d);

  final DashData d;

  @override
  Widget build(BuildContext context) {
    final series = <(List<double>, Color)>[
      (d.shopeeWeek, Pal.shopee),
      (d.tiktokWeek, Pal.tiktok),
      (d.lazadaWeek, Pal.lazada),
    ].where((s) => s.$1.isNotEmpty).toList();
    final values = [for (final s in series) ...s.$1].where((v) => v.isFinite);
    final peak = values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = peak < 10 ? 10.0 : peak * 1.2;
    if (series.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)));
    }
    return CustomPaint(
      painter: _TrendPainter(labels: d.weekLabels, series: series, maxY: maxY),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.labels,
    required this.series,
    required this.maxY,
  });

  final List<String> labels;
  final List<(List<double>, Color)> series;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const bottom = 28.0;
    const top = 8.0;
    const right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0 || !maxY.isFinite || maxY <= 0) return;

    final grid = Paint()
      ..color = Pal.line
      ..strokeWidth = 1;
    const rows = 5;
    for (var i = 0; i <= rows; i++) {
      final y = top + h * i / rows;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: (maxY * (1 - i / rows)).round().toString(),
          style: const TextStyle(fontSize: 11, color: Pal.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    final n = series.map((s) => s.$1.length).fold<int>(0, (a, b) => a > b ? a : b);
    if (n == 0) return;

    Offset at(int i, double raw) {
      final v = raw.isFinite ? raw.clamp(0, maxY) : 0.0;
      final x = n == 1 ? left + w / 2 : left + w * i / (n - 1);
      final y = top + h * (1 - v / maxY);
      return Offset(x, y);
    }

    for (final s in series) {
      if (s.$1.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.$1.length; i++) {
        final p = at(i, s.$1[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    final count = labels.isEmpty ? n : math.min(labels.length, n);
    for (var i = 0; i < count; i++) {
      final text = labels.isEmpty ? '${i + 1}' : labels[i];
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 11, color: Pal.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (n == 1 ? left + w / 2 : left + w * i / (n - 1)) - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, size.width - tp.width), top + h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.labels != labels || old.series != series || old.maxY != maxY;
}

class _Share extends StatelessWidget {
  const _Share(this.d);

  final DashData d;

  @override
  Widget build(BuildContext context) {
    final slices = <(double, Color, String, int)>[
      (d.shopeeShare, Pal.shopee, 'Shopee', _countFromShare(d.totalOrders, d.shopeeShare)),
      (d.tiktokShare, Pal.tiktok, 'TikTok Shop', _countFromShare(d.totalOrders, d.tiktokShare)),
      (d.lazadaShare, Pal.lazada, 'Lazada', _countFromShare(d.totalOrders, d.lazadaShare)),
    ].where((e) => e.$1.isFinite && e.$1 > 0).toList();
    if (slices.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)));
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
      children: [
        SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: const Size(168, 168), painter: _PiePainter(slices)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d.totalOrders}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('รายการ', style: TextStyle(color: Pal.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < slices.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _Dot(color: slices[i].$2, text: '${slices[i].$3}  ${slices[i].$1.toStringAsFixed(0)}% (${slices[i].$4})'),
              ],
            ],
          ),
        ),
      ],
    ),
    );
  }
}

int _countFromShare(int total, double share) {
  if (total <= 0 || !share.isFinite) return 0;
  return (total * share / 100).round();
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices);

  final List<(double, Color, String, int)> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    if (r < 8) return;
    final total = slices.fold<double>(0, (a, b) => a + b.$1);
    if (!total.isFinite || total <= 0) return;

    var start = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    for (final s in slices) {
      final sweep = (s.$1 / total) * 2 * math.pi;
      canvas.drawArc(rect, start, sweep - 0.02, true, Paint()..color = s.$2);
      start += sweep;
    }
    canvas.drawCircle(center, r * 0.58, Paint()..color = Colors.white);

    start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.$1 / total) * 2 * math.pi;
      if (sweep > 0.35) {
        final mid = start + sweep / 2;
        final labelR = r * 0.78;
        final tp = TextPainter(
          text: TextSpan(
            text: '${s.$1.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(center.dx + math.cos(mid) * labelR - tp.width / 2, center.dy + math.sin(mid) * labelR - tp.height / 2),
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.slices != slices;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
