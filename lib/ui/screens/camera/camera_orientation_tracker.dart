import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CameraOrientationTracker {
  StreamSubscription<AccelerometerEvent>? _subscription;
  double _lastTurns = 0.0;

  void start(ValueChanged<double> onChanged) {
    _subscription?.cancel();
    _subscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((event) {
          final double? nextTurns = _turnsFromAccelerometer(event);
          if (nextTurns == null || (_lastTurns - nextTurns).abs() < 0.01) {
            return;
          }

          _lastTurns = nextTurns;
          onChanged(nextTurns);
        });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  double? _turnsFromAccelerometer(AccelerometerEvent event) {
    final double x = event.x;
    final double y = event.y;
    if (x.abs() < 5.8 && y.abs() < 5.8) return null;

    if (x.abs() > y.abs()) {
      return x > 0 ? 0.25 : -0.25;
    }
    return y > 0 ? 0.0 : 0.5;
  }
}
