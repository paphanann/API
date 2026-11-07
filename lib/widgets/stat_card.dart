import 'package:flutter/material.dart';

import '../app/theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
    this.trailing,
    this.dark = false,
    this.compact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? hint;
  final Widget? trailing;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? const EdgeInsets.fromLTRB(10, 8, 10, 8) : const EdgeInsets.fromLTRB(14, 12, 14, 10);
    final iconBox = compact ? 28.0 : 36.0;
    return Container(
      decoration: BoxDecoration(
        color: dark ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: dark ? null : Border.all(color: Pal.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!dark)
            ColoredBox(
              color: color.withValues(alpha: 0.14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Padding(
            padding: pad,
            child: Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withValues(alpha: 0.12) : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: compact ? 16 : 20, color: dark ? Colors.white : color),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dark)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700),
                        ),
                      Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                style: TextStyle(
                                  color: dark ? Colors.white : Pal.text,
                                  fontSize: compact ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 6),
                            trailing!,
                          ],
                        ],
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 1),
                        hint!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
