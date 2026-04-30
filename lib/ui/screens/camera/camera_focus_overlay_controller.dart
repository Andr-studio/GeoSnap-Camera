import 'dart:async';

import 'package:flutter/widgets.dart';

class CameraFocusOverlayController {
  Timer? _hideTimer;

  Offset? point;
  bool locked = false;
  bool visible = false;
  bool exposureVisible = false;
  double brightness = 0.5;

  void show({
    required Offset newPoint,
    required bool lockFocus,
    required bool showExposure,
  }) {
    _hideTimer?.cancel();
    point = newPoint;
    locked = lockFocus;
    visible = true;
    exposureVisible = showExposure;
  }

  void updateBrightness(double value) {
    brightness = value.clamp(0.0, 1.0).toDouble();
    visible = true;
    exposureVisible = true;
  }

  void scheduleHide(VoidCallback onChanged) {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (locked) return;
      visible = false;
      exposureVisible = false;
      onChanged();
    });
  }

  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}
