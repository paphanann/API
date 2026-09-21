import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';

class DateRangeField extends StatelessWidget {
  const DateRangeField({super.key, required this.from, required this.to, required this.onTap});

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = from != null && to != null;
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ช่วงวันที่', style: TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                has ? '${dayFmt.format(from!)} - ${dayFmt.format(to!)}' : 'ทั้งหมด',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: has ? null : Pal.muted,
                ),
              ),
            ),
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
            initialValue: items.any((e) => e.value == value) ? value : null,
            items: items,
            onChanged: onChanged,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
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
      return Material(
        color: on ? Pal.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: on ? Pal.primary : Pal.line),
        ),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 34, height: 34, child: Center(child: child)),
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
