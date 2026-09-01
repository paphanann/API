import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 36, this.withName = true, this.light = false});

  final double size;
  final bool withName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.48,
          height: 1,
        ),
      ),
    );

    if (!withName) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: size * 0.28),
        Text(
          'PASS',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: light ? Colors.white : Pal.text,
          ),
        ),
      ],
    );
  }
}

class ChannelDot extends StatelessWidget {
  const ChannelDot({super.key, required this.channel, this.size = 22});

  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = channel == Channel.tiktok ? Pal.tiktokHi : Colors.white;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: channel.color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        channel.mark,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.48, height: 1),
      ),
    );
  }
}

class ChannelLabel extends StatelessWidget {
  const ChannelLabel({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChannelDot(channel: channel, size: 20),
        const SizedBox(width: 8),
        Text(channel.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: channel.color)),
      ],
    );
  }
}

Widget pill(String text, Color fg, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

Widget orderPill(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return pill('Pending', const Color(0xFFB45309), Pal.warnBg);
    case OrderStatus.success:
      return pill('Success', const Color(0xFF15803D), Pal.okBg);
    case OrderStatus.cancelled:
      return pill('Canceled', const Color(0xFFB91C1C), Pal.errBg);
  }
}

Widget syncPill(SyncStatus s) {
  switch (s) {
    case SyncStatus.success:
      return pill('Success', const Color(0xFF15803D), Pal.okBg);
    case SyncStatus.error:
      return pill('Error', const Color(0xFFB91C1C), Pal.errBg);
    case SyncStatus.pending:
      return pill('Pending', const Color(0xFFB45309), Pal.warnBg);
  }
}

Widget productPill(ProductStatus s) {
  switch (s) {
    case ProductStatus.active:
      return pill('พร้อมขาย', const Color(0xFF15803D), Pal.okBg);
    case ProductStatus.inactive:
      return pill('ปิดขาย', const Color(0xFFB91C1C), Pal.errBg);
    case ProductStatus.draft:
      return pill('ฉบับร่าง', Pal.muted, const Color(0xFFF3F4F6));
  }
}

Widget connPill(ConnStatus s) {
  switch (s) {
    case ConnStatus.waiting:
      return pill('รออนุมัติ', const Color(0xFFB45309), Pal.warnBg);
    case ConnStatus.sandbox:
      return pill('Sandbox Connected', Pal.primary, Pal.infoBg);
    case ConnStatus.live:
      return pill('เชื่อมต่อแล้ว', const Color(0xFF15803D), Pal.okBg);
    case ConnStatus.off:
      return pill('ยังไม่เชื่อมต่อ', Pal.muted, const Color(0xFFF3F4F6));
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.pad});

  final Widget child;
  final String? title;
  final EdgeInsets? pad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          Padding(padding: pad ?? const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.dark = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: dark ? null : Border.all(color: Pal.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: dark ? Colors.white70 : Pal.muted, fontSize: 13)),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: dark ? Colors.white : Pal.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.12) : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: dark ? Colors.white : color),
          ),
        ],
      ),
    );
  }
}

class Drop<T> extends StatelessWidget {
  const Drop({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            key: ValueKey(value),
            initialValue: value,
            items: items,
            onChanged: onChanged,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class Pages extends StatelessWidget {
  const Pages({super.key, required this.page, required this.total, required this.onTap});

  final int page;
  final int total;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final shown = <int>[];
    for (var i = 1; i <= total && i <= 5; i++) {
      shown.add(i);
    }

    Widget btn(Widget child, VoidCallback? tap, {bool on = false}) {
      return InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Pal.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? Pal.primary : Pal.line),
          ),
          child: child,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        btn(Icon(Icons.chevron_left, size: 18, color: page > 1 ? Pal.text : Pal.faint), page > 1 ? () => onTap(page - 1) : null),
        const SizedBox(width: 6),
        for (final n in shown) ...[
          btn(
            Text('$n', style: TextStyle(color: n == page ? Colors.white : Pal.text, fontWeight: FontWeight.w600, fontSize: 13)),
            () => onTap(n),
            on: n == page,
          ),
          const SizedBox(width: 6),
        ],
        if (total > 5) ...[
          const Text('…', style: TextStyle(color: Pal.muted)),
          const SizedBox(width: 6),
          btn(Text('$total', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), () => onTap(total)),
          const SizedBox(width: 6),
        ],
        btn(Icon(Icons.chevron_right, size: 18, color: page < total ? Pal.text : Pal.faint), page < total ? () => onTap(page + 1) : null),
      ],
    );
  }
}

const tableHead = TextStyle(fontWeight: FontWeight.w700, color: Pal.muted, fontSize: 13);
const tableHeadBg = WidgetStatePropertyAll(Color(0xFFF8FAFC));

/// ยืดตารางให้เต็มความกว้างการ์ด ถ้าจอแคบค่อยเลื่อนข้าง
class FillTable extends StatelessWidget {
  const FillTable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
