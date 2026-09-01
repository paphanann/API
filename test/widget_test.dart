import 'package:flutter_test/flutter_test.dart';
import 'package:pass/main.dart';
import 'package:pass/session.dart';

void main() {
  testWidgets('login page ขึ้นมา', (tester) async {
    await tester.pumpWidget(PassApp(session: Session()));
    await tester.pump();
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
