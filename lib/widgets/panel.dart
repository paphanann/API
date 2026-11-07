import 'package:flutter/material.dart';

import '../app/theme.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.pad,
    this.expand = false,
    this.dense = false,
    this.titleColor,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets? pad;
  final bool expand;
  final bool dense;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: pad ?? (dense ? const EdgeInsets.fromLTRB(14, 0, 14, 12) : const EdgeInsets.fromLTRB(20, 0, 20, 20)), child: child);
    final content = expand ? Expanded(child: body) : body;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      alignment: expand ? Alignment.topLeft : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? 12 : 14),
        border: Border.all(color: Pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: dense ? const EdgeInsets.fromLTRB(12, 10, 8, 10) : const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: dense ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor ?? Pal.text,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
            ),
          content,
        ],
      ),
    );
  }
}
