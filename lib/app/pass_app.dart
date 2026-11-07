import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import 'session.dart';
import 'theme.dart';

class PassScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class PassApp extends StatefulWidget {
  const PassApp({super.key, required this.session});

  final Session session;

  @override
  State<PassApp> createState() => _PassAppState();
}

class _PassAppState extends State<PassApp> {
  late final _router = buildRouter(widget.session);

  @override
  void initState() {
    super.initState();
    widget.session.resolveRole();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pass Marketplace',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scrollBehavior: PassScrollBehavior(),
      routerConfig: _router,
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('th', 'TH'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
