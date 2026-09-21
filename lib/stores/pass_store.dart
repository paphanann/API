import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// ไม่กระทุ้ง UI ตอนกำลัง build — กัน Unexpected null / setState during build
class PassStore extends ChangeNotifier {
  @override
  void notifyListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }
}
