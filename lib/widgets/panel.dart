import 'package:flutter/material.dart';

import '../app/theme.dart';

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
