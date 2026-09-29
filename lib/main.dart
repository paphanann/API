import 'package:flutter/material.dart';

import 'app/pass_app.dart';
import 'app/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(PassApp(session: Session()));
}