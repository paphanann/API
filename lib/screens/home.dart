import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../stores/stores.dart';
import '../widgets/sync_status.dart';
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
    TransferStore.instance,
    Session.instance,
  ]);

  DateTime? _from = DateTime(2026, 10, 1);
  DateTime? _to;
  String _ch = 'all';
  String _shop = 'all';
  bool _sapOn = false;
  int _recentPage = 1;
  static const _recentSize = 20;
  List<Order> _recent = [];
  int _recentTotal = 0;
  bool _recentLoading = false;
  int _recentReq = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _to = today;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ShopStore.instance.load();
      TransferStore.instance.load();
      _loadSap();
      _reload();
    });
  }

  Future<void> _loadSap() async {
    try {
      final s = await Api.getSettings();
      if (!mounted) return;
      setState(() {
        _sapOn = s.database.trim().isNotEmpty && (s.host.trim().isNotEmpty || s.endpoint.trim().isNotEmpty);
      });
    } catch (_) {}
  }

  DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  void _applyPeriod(DatePeriod period) {
    if (period == DatePeriod.custom) {
      _pickRange().whenComplete(() {
        if (mounted) setState(() {});
      });
      return;
    }
    final range = rangeOfPeriod(period);
    setState(() {
      _from = range.$1;
      _to = range.$2;
      _recentPage = 1;
    });
    _reload();
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
      _recentPage = 1;
    });
    _reload();
  }

  String? get _platformQuery {
    if (_ch != 'all') return Channel.values.byName(_ch).apiPlatform;
    if (_shop == 'all') return null;
    final name = _shop.split('|').first;
    final channel = Channel.values.where((c) => c.name == name);
    return channel.isEmpty ? null : channel.first.apiPlatform;
  }

  String? get _shopQuery {
    if (_shop == 'all') return null;
    final cut = _shop.indexOf('|');
    final id = cut >= 0 ? _shop.substring(cut + 1) : _shop;
    if (id.isEmpty || id == '-') return null;
    return id;
  }

  int _transferCount() {
    var n = 0;
    for (final t in TransferStore.instance.rows) {
      final at = t.displayAt;
      if (_from != null && _to != null) {
        if (at == null) continue;
        if (!inDayRange(at, _from, _to)) continue;
      }
      if (_ch != 'all') {
        final ch = ChannelX.fromApi(t.platform);
        if (ch == null || ch.name != _ch) continue;
      }
      n++;
    }
    return n;
  }

  Future<void> _reload() async {
    _recentPage = _recentPage < 1 ? 1 : _recentPage;
    await Future.wait([
      DashStore.instance.load(from: _from, to: _to, platform: _platformQuery, shopId: _shopQuery),
      TransferStore.instance.load(),
    ]);
    if (_recentPage > 1) await _loadRecent();
  }

  Future<void> _loadRecent() async {
    final req = ++_recentReq;
    setState(() => _recentLoading = true);
    try {
      final page = await Api.getOrdersPage(
        platform: _platformQuery,
        shopId: _shopQuery,
        from: _from,
        to: _to,
        page: _recentPage,
        pageSize: _recentSize,
      );
      if (!mounted || req != _recentReq) return;
      setState(() {
        _recent = page.items;
        _recentTotal = page.total;
        _recentLoading = false;
      });
    } catch (_) {
      if (!mounted || req != _recentReq) return;
      setState(() => _recentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        final dash = DashStore.instance;
        final shops = ShopStore.instance.shops;
        final scopedShops = _ch == 'all' ? shops : shops.where((s) => s.channel.name == _ch).toList();
        final d = dash.data;
        final liveChannels = {
          for (final s in scopedShops)
            if (s.isReal) s.channel,
        };
        final connectedN = liveChannels.length + (_sapOn ? 1 : 0);
        const shopTotal = 4;
        final productCount = d.productCount;
        final soCount = d.soCount;
        final deliveryCount = d.deliveryCount;
        final transferCount = _transferCount();

        return LayoutBuilder(
          builder: (context, viewport) {
            final screen = MediaQuery.sizeOf(context);
            final maxH = viewport.maxHeight.isFinite && viewport.maxHeight > 0 ? viewport.maxHeight : screen.height - 68;
            final maxW = viewport.maxWidth.isFinite && viewport.maxWidth > 0 ? viewport.maxWidth : screen.width;
            final fill = maxH >= 560 && maxW >= 960;
            const pad = EdgeInsets.fromLTRB(20, 12, 20, 16);
            final body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('หน้าหลัก (Dashboard)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  TopBarLastSync(),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final filters = [
                    DateRangeField(from: _from, to: _to, onTap: _pickRange),
                    PeriodField(value: periodOfRange(_from, _to), onChanged: _applyPeriod),
                    Drop<String>(
                      label: 'แพลตฟอร์ม',
                      value: _ch,
                      width: 160,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                        for (final c in Channel.values) DropdownMenuItem(value: c.name, child: Text(c.shortLabel)),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _ch = v ?? 'all';
                          _shop = 'all';
                          _recentPage = 1;
                        });
                        _reload();
                      },
                    ),
                    Drop<String>(
                      label: 'ร้านค้า',
                      value: _shop,
                      width: 180,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('ทุกร้าน')),
                        for (final s in ShopStore.instance.realShops)
                          if (s.connected && s.apiShopId.isNotEmpty && (_ch == 'all' || s.channel.name == _ch))
                            DropdownMenuItem(
                              value: '${s.channel.name}|${s.apiShopId}',
                              child: Text(s.displayName),
                            ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _shop = v ?? 'all';
                          _recentPage = 1;
                        });
                        _reload();
                      },
                    ),
                  ];
                  final sync = HeaderSyncActions(
                    showLabel: false,
                    onDone: () async {
                      if (_recentPage > 1) await _loadRecent();
                    },
                  );
                  if (box.maxWidth < 1100) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [...filters, sync],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < filters.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        filters[i],
                      ],
                      const SizedBox(width: 12),
                      Padding(padding: const EdgeInsets.only(bottom: 1), child: sync),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
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
              if (dash.loading || _recentLoading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(minHeight: 3)),
              LayoutBuilder(
                builder: (context, c) {
                  final cards = [
                    StatCard(
                      compact: true,
                      title: 'คำสั่งซื้อทั้งหมด',
                      value: nFmt.format(d.totalOrders),
                      icon: Icons.shopping_cart_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                    StatCard(
                      compact: true,
                      title: 'สินค้าทั้งหมด',
                      value: nFmt.format(productCount),
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                    StatCard(
                      compact: true,
                      title: 'สร้าง Sales Order (SO)',
                      value: nFmt.format(soCount),
                      icon: Icons.description_outlined,
                      color: const Color(0xFFF59E0B),
                    ),
                    StatCard(
                      compact: true,
                      title: 'สร้าง Delivery',
                      value: nFmt.format(deliveryCount),
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFF06B6D4),
                    ),
                    StatCard(
                      compact: true,
                      title: 'สร้าง Transfer Request',
                      value: nFmt.format(transferCount),
                      icon: Icons.swap_horiz_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    StatCard(
                      compact: true,
                      title: 'เชื่อมต่อระบบ',
                      value: '$connectedN/$shopTotal',
                      icon: Icons.power_outlined,
                      color: Pal.ok,
                    ),
                  ];
                  if (c.maxWidth >= 1280) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  }
                  final cols = c.maxWidth >= 900 ? 3 : 2;
                  final w = (c.maxWidth - (cols - 1) * 10) / cols;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final card in cards) SizedBox(width: w, child: card)],
                  );
                },
              ),
              const SizedBox(height: 10),
              if (fill)
                Expanded(flex: 6, child: _chartRow(d, shops, fill: true))
              else
                _chartRow(d, shops, fill: false),
              const SizedBox(height: 10),
              if (fill)
                Expanded(flex: 5, child: _bottomRow(d, fill: true))
              else
                _bottomRow(d, fill: false),
            ],
            );
            if (fill) {
              return SizedBox(height: maxH, child: Padding(padding: pad, child: body));
            }
            return SingleChildScrollView(padding: pad, child: body);
          },
        );
      },
    );
  }

  Widget _chartRow(DashData d, List<ShopConn> shops, {required bool fill}) {
    Widget trend({required bool expand}) => Panel(
          dense: true,
          expand: expand,
          title: 'จำนวนคำสั่งซื้อ 7 วันล่าสุด',
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
          pad: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: expand
              ? SizedBox.expand(child: _Trend(d))
              : SizedBox(width: double.infinity, height: 200, child: _Trend(d)),
        );
    Widget conns({required bool expand}) => Panel(
          dense: true,
          expand: expand,
          title: 'สถานะการเชื่อมต่อ',
          trailing: Session.instance.isUserRole
              ? null
              : TextButton(
                  onPressed: () => context.go('/connections'),
                  child: const Text('ดูทั้งหมด →'),
                ),
          child: _ConnList(shops: shops, sapOn: _sapOn),
        );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: trend(expand: true)),
        const SizedBox(width: 10),
        Expanded(child: conns(expand: true)),
      ],
    );
    if (fill) return row;
    return SizedBox(height: 236, child: row);
  }

  Widget _bottomRow(DashData d, {required bool fill}) {
    final share = Panel(
      dense: true,
      expand: fill,
      title: 'สัดส่วนคำสั่งซื้อ',
      child: fill ? Center(child: _Share(d)) : SizedBox(height: 156, child: _Share(d)),
    );
    final recent = Panel(
      dense: true,
      expand: fill,
      title: 'คำสั่งซื้อล่าสุด',
      trailing: TextButton(
        onPressed: () => context.go('/orders'),
        child: const Text('ดูทั้งหมด →'),
      ),
      pad: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: _RecentOrders(
        orders: _recentPage == 1 ? d.recent : _recent,
        total: _recentPage == 1 ? d.totalOrders : _recentTotal,
        page: _recentPage,
        pageSize: _recentSize,
        loading: _recentPage == 1 ? DashStore.instance.loading : _recentLoading,
        onPage: (p) {
          if (p == _recentPage) return;
          setState(() => _recentPage = p);
          _loadRecent();
        },
      ),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: share),
        const SizedBox(width: 10),
        Expanded(flex: 7, child: recent),
      ],
    );
    if (fill) return row;
    return IntrinsicHeight(child: row);
  }
}

bool _skipped(Order o) => o.status == OrderStatus.cancelled || o.status == OrderStatus.returned;

bool _hasSo(Order o) => o.sapDocNum != null && o.sapDocNum!.trim().isNotEmpty;

bool _hasDelivery(Order o) => (o.deliveryDocNum ?? '').trim().isNotEmpty;

class _ConnList extends StatelessWidget {
  const _ConnList({required this.shops, required this.sapOn});

  final List<ShopConn> shops;
  final bool sapOn;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final c in Channel.values) _platformRow(context, c),
      _sapRow(context),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Pal.line),
          items[i],
        ],
      ],
    );
  }

  List<ShopConn> _of(Channel c) => [for (final s in shops) if (s.channel == c && s.isReal) s];

  Widget _platformRow(BuildContext context, Channel c) {
    final list = _of(c);
    final total = list.length;
    final live = list.where((s) => s.connected).length;
    final complete = total > 0 && live == total;
    return _row(
      leading: ChannelDot(channel: c, size: 32),
      title: c.label,
      badge: pill(
        '$live/$total ร้าน',
        complete ? Pal.ok : const Color(0xFFC2410C),
        complete ? Pal.okBg : const Color(0xFFFFEDD5),
        size: 11,
      ),
      onOpen: () => context.go('/connections'),
    );
  }

  Widget _sapRow(BuildContext context) {
    return _row(
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Pal.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text('SAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9, height: 1)),
      ),
      title: 'SAP B1',
      badge: sapOn
          ? pill('เชื่อมต่อแล้ว', Pal.ok, Pal.okBg, size: 11)
          : pill('ยังไม่เชื่อมต่อ', Pal.err, Pal.errBg, size: 11),
      onOpen: () => context.go('/settings'),
    );
  }

  Widget _row({
    required Widget leading,
    required String title,
    required Widget badge,
    required VoidCallback onOpen,
  }) {
    return InkWell(
      onTap: Session.instance.isUserRole ? null : onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            badge,
          ],
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({
    required this.orders,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.loading,
    required this.onPage,
  });

  final List<Order> orders;
  final int total;
  final int page;
  final int pageSize;
  final bool loading;
  final ValueChanged<int> onPage;
  static const _flex = [3, 2, 2, 2, 2];

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(loading ? 'กำลังโหลด...' : 'ไม่พบคำสั่งซื้อ', style: const TextStyle(color: Pal.muted))),
      );
    }
    final pages = (total / pageSize).ceil().clamp(1, 9999);
    final cur = page.clamp(1, pages);
    final start = (cur - 1) * pageSize;
    final rows = orders;
    final fromN = start + 1;
    final toN = start + rows.length;
    const head = ColoredBox(
      color: Color(0xFFF1F5F9),
      child: _MiniHead(cells: ['#', 'คำสั่งซื้อ', 'แพลตฟอร์ม', 'วันที่', 'ยอดรวม', 'สถานะ SAP'], flex: _flex),
    );
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          const Divider(height: 1, color: Pal.line),
          ColoredBox(
            color: i.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
            child: _MiniRow(
              flex: _flex,
              onTap: () => context.go('/orders/${Uri.encodeComponent(rows[i].id)}'),
              cells: [
                Text('${start + i + 1}', style: const TextStyle(color: Pal.muted, fontSize: 12)),
                Tooltip(
                  message: rows[i].id,
                  child: Text(
                    rows[i].id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                Text(rows[i].channel.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                Text(dayFmt.format(rows[i].createdAt), maxLines: 1, style: const TextStyle(fontSize: 12, color: Pal.muted)),
                Text(baht.format(rows[i].total), maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                _orderSap(rows[i]),
              ],
            ),
          ),
        ],
      ],
    );
    final footer = Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'แสดง $fromN - $toN จาก $total รายการ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pal.muted, fontSize: 12),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Pages(page: cur, total: pages, onTap: onPage),
          ),
        ],
      ),
    );
    Widget frame(Widget child) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Pal.line),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        if (!box.maxHeight.isFinite) {
          return Column(mainAxisSize: MainAxisSize.min, children: [frame(Column(children: [head, body])), footer]);
        }
        return Column(
          children: [
            Expanded(
              child: frame(
                Column(
                  children: [
                    head,
                    Expanded(child: VScrollPane(child: body)),
                  ],
                ),
              ),
            ),
            footer,
          ],
        );
      },
    );
  }

  Widget _orderSap(Order o) {
    if (_skipped(o)) {
      return const Text('—', style: TextStyle(color: Pal.muted, fontSize: 12));
    }
    if (_hasDelivery(o)) return dashDeliveryPill(size: 11);
    if (_hasSo(o)) return dashSoPill(size: 11);
    return waitSoPill(size: 11);
  }
}

class _MiniHead extends StatelessWidget {
  const _MiniHead({required this.cells, this.flex = const []});

  final List<String> cells;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            if (i == 0)
              SizedBox(
                width: 40,
                child: Text(cells[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tableHead),
              )
            else
              Expanded(
                flex: i - 1 < flex.length ? flex[i - 1] : 1,
                child: Text(cells[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tableHead),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++)
                if (i == 0)
                  SizedBox(width: 40, child: Align(alignment: Alignment.centerLeft, child: cells[i]))
                else
                  Expanded(
                    flex: i - 1 < flex.length ? flex[i - 1] : 1,
                    child: Align(alignment: Alignment.centerLeft, child: cells[i]),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trend extends StatefulWidget {
  const _Trend(this.d);

  final DashData d;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  int? _hover;
  Offset? _cursor;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final named = <(List<double>, Color, String)>[
      (d.shopeeWeek, Pal.shopee, 'Shopee'),
      (d.tiktokWeek, Pal.tiktok, 'TikTok Shop'),
      (d.lazadaWeek, Pal.lazada, 'Lazada'),
    ];
    final series = [for (final s in named) (s.$1, s.$2)];
    final values = [for (final s in series) ...s.$1].where((v) => v.isFinite);
    final peak = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (peak <= 0 && d.weekLabels.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Pal.muted)));
    }
    final n = math.max(
      d.weekLabels.length,
      series.map((s) => s.$1.length).fold<int>(0, (a, b) => a > b ? a : b),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return MouseRegion(
          onHover: (e) {
            final i = _barHitIndex(e.localPosition, size, n);
            setState(() {
              _hover = i;
              _cursor = e.localPosition;
            });
          },
          onExit: (_) => setState(() {
            _hover = null;
            _cursor = null;
          }),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: size,
                painter: _BarPainter(labels: d.weekLabels, series: series, maxY: _niceMax(peak), hover: _hover),
              ),
              if (_hover != null && _cursor != null)
                _BarTip(
                  cursor: _cursor!,
                  size: size,
                  label: _hover! < d.weekLabels.length ? d.weekLabels[_hover!] : '${_hover! + 1}',
                  rows: [
                    for (final s in named)
                      (s.$3, s.$2, _hover! < s.$1.length ? s.$1[_hover!].round() : 0),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

int? _barHitIndex(Offset pos, Size size, int n) {
  if (n <= 0 || size.width <= 0) return null;
  const left = 44.0;
  const right = 8.0;
  const top = 20.0;
  const bottom = 28.0;
  final w = size.width - left - right;
  if (w <= 0) return null;
  if (pos.dx < left || pos.dx > left + w) return null;
  if (pos.dy < top || pos.dy > size.height - bottom) return null;
  final i = ((pos.dx - left) / (w / n)).floor();
  if (i < 0 || i >= n) return null;
  return i;
}

class _BarTip extends StatelessWidget {
  const _BarTip({
    required this.cursor,
    required this.size,
    required this.label,
    required this.rows,
  });

  final Offset cursor;
  final Size size;
  final String label;
  final List<(String, Color, int)> rows;

  @override
  Widget build(BuildContext context) {
    const tipW = 188.0;
    var left = cursor.dx + 12;
    var top = cursor.dy - 88;
    if (left + tipW > size.width) left = cursor.dx - tipW - 12;
    if (left < 0) left = 8;
    if (top < 0) top = cursor.dy + 16;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: SizedBox(
              width: 162,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Pal.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: rows[i].$2, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rows[i].$1, style: const TextStyle(fontSize: 12))),
                        Text(nFmt.format(rows[i].$3), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _niceMax(double peak) {
  if (peak <= 0) return 10;
  final padded = peak * 1.08;
  final mag = math.pow(10, (math.log(padded) / math.ln10).floor()).toDouble();
  final n = padded / mag;
  final nice = n <= 1 ? 1.0 : n <= 2 ? 2.0 : n <= 2.5 ? 2.5 : n <= 5 ? 5.0 : 10.0;
  return nice * mag;
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.labels,
    required this.series,
    required this.maxY,
    this.hover,
  });

  final List<String> labels;
  final List<(List<double>, Color)> series;
  final double maxY;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const bottom = 28.0;
    const top = 20.0;
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
          text: nFmt.format((maxY * (1 - i / rows)).round()),
          style: const TextStyle(fontSize: 11, color: Pal.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    final n = math.max(
      labels.length,
      series.map((s) => s.$1.length).fold<int>(0, (a, b) => a > b ? a : b),
    );
    if (n == 0) return;

    final groupW = w / n;
    final innerPad = groupW * 0.18;
    final inner = (groupW - innerPad).clamp(4.0, groupW);
    final barW = inner / series.length;

    if (hover != null && hover! >= 0 && hover! < n) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + hover! * groupW, top, groupW, h),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFF1F5F9),
      );
    }

    for (var i = 0; i < n; i++) {
      final groupX = left + i * groupW + innerPad / 2;
      for (var s = 0; s < series.length; s++) {
        final raw = i < series[s].$1.length ? series[s].$1[i] : 0.0;
        final v = raw.isFinite ? raw.clamp(0, maxY) : 0.0;
        final bh = h * (v / maxY);
        if (bh <= 0) continue;
        final x = groupX + s * barW;
        final rect = Rect.fromLTWH(x, top + h - bh, barW * 0.82, bh);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = series[s].$2,
        );
      }
    }

    for (var i = 0; i < n; i++) {
      final text = i < labels.length ? labels[i] : '${i + 1}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 11, color: Pal.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = left + i * groupW + groupW / 2 - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, size.width - tp.width), top + h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.labels != labels || old.series != series || old.maxY != maxY || old.hover != hover;
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
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxHeight.isFinite && box.maxHeight > 0
            ? box.maxHeight.clamp(120.0, 176.0)
            : 132.0;
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: Size(size, size), painter: _PiePainter(slices)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nFmt.format(d.totalOrders), style: TextStyle(fontSize: size >= 150 ? 20 : 18, fontWeight: FontWeight.w800)),
                        const Text('รายการ', style: TextStyle(color: Pal.muted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < slices.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _Dot(color: slices[i].$2, text: '${slices[i].$3} ${slices[i].$1.toStringAsFixed(0)}% (${nFmt.format(slices[i].$4)})'),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
        Flexible(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
