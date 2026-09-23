import 'package:flutter/material.dart';

import '../app/theme.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.trailing, this.pad, this.expand = false});

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets? pad;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: pad ?? const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
            ),
          if (expand) Expanded(child: ClipRect(child: body)) else body,
        ],
      ),
    );
  }
}
