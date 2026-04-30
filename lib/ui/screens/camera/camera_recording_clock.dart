import 'dart:async';

import 'package:flutter/foundation.dart';

class CameraRecordingClock {
  Timer? _timer;
  Duration elapsed = Duration.zero;

  bool get isRunning => _timer != null;

  String get label {
    final int totalSeconds = elapsed.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void start(VoidCallback onChanged) {
    _timer?.cancel();
    elapsed = Duration.zero;
    onChanged();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed += const Duration(seconds: 1);
      onChanged();
    });
  }

  void stop({bool reset = true, VoidCallback? onChanged}) {
    _timer?.cancel();
    _timer = null;
    if (reset) {
      elapsed = Duration.zero;
      onChanged?.call();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
