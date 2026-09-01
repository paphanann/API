import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'routes.dart';
import 'session.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  runApp(PassApp(session: Session()));
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
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PASS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
