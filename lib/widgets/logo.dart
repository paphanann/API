import 'package:flutter/material.dart';

import '../app/theme.dart';

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
