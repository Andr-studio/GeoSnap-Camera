import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GeoSnapCameraController {
  static const int imageModeIndex = 0;
  static const int videoModeIndex = 1;
  static const Duration shutterDebounce = Duration(milliseconds: 220);

  final List<String> modes = const <String>['Imagen', 'Video'];
  final ValueNotifier<int> selectedModeNotifier = ValueNotifier<int>(
    imageModeIndex,
  );
  late final PageController modePageController = PageController(
    initialPage: selectedModeNotifier.value,
  );
  late final PageController bottomPageController = PageController(
    initialPage: selectedModeNotifier.value,
    viewportFraction: 0.22,
  );

  int _pendingCameraMode = imageModeIndex;
  bool _isCaptureActionInProgress = false;
  bool _isModeChangeInProgress = false;
  DateTime? _lastShutterTapAt;

  void dispose() {
    modePageController.dispose();
    bottomPageController.dispose();
    selectedModeNotifier.dispose();
  }

  Future<void> switchCamera(
    CameraState state, {
    required VoidCallback closeFlashMenu,
    required Future<void> Function() onCameraSwitched,
  }) async {
    if (state is VideoRecordingCameraState) return;
    closeFlashMenu();
    await state.switchCameraSensor();
    await onCameraSwitched();
  }

  void onPageChanged(int index) {
    if (index == selectedModeNotifier.value) return;

    HapticFeedback.mediumImpact();
    selectedModeNotifier.value = index;
  }

  void onModeTap(
    int index,
    CameraState state, {
    required VoidCallback stopRecordingClock,
  }) {
    if (state is VideoRecordingCameraState) return;
    modePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    bottomPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    if (selectedModeNotifier.value != index) {
      HapticFeedback.mediumImpact();
      selectedModeNotifier.value = index;
    }
    unawaited(applyHardwareMode(state, stopRecordingClock: stopRecordingClock));
  }

  Future<void> applyHardwareMode(
    CameraState state, {
    required VoidCallback stopRecordingClock,
  }) async {
    if (_isModeChangeInProgress) return;
    final int selectedIndex = selectedModeNotifier.value;
    if (_pendingCameraMode == selectedIndex) return;
    _isModeChangeInProgress = true;

    try {
      if (state is VideoRecordingCameraState &&
          selectedIndex != videoModeIndex) {
        await state.stopRecording();
        stopRecordingClock();
      }

      if (selectedIndex == imageModeIndex) {
        state.setState(CaptureMode.photo);
      } else if (selectedIndex == videoModeIndex) {
        state.setState(CaptureMode.video);
      }
      _pendingCameraMode = selectedIndex;
    } finally {
      _isModeChangeInProgress = false;
    }
  }

  Future<void> handleShutterTap(
    CameraState state, {
    required VoidCallback startRecordingClock,
    required VoidCallback stopRecordingClock,
  }) async {
    if (_isCaptureActionInProgress) return;
    final DateTime now = DateTime.now();
    if (_lastShutterTapAt != null &&
        now.difference(_lastShutterTapAt!) < shutterDebounce) {
      return;
    }
    _lastShutterTapAt = now;
    _isCaptureActionInProgress = true;

    try {
      await applyHardwareMode(state, stopRecordingClock: stopRecordingClock);
      final bool wantsVideo = selectedModeNotifier.value == videoModeIndex;

      if (wantsVideo) {
        if (state is VideoRecordingCameraState) {
          await state.stopRecording();
          stopRecordingClock();
        } else if (state is VideoCameraState) {
          await state.startRecording();
          startRecordingClock();
        } else {
          state.setState(CaptureMode.video);
        }
      } else {
        if (state is PhotoCameraState) {
          await state.takePhoto();
        } else if (state is VideoRecordingCameraState) {
          await state.stopRecording();
          stopRecordingClock();
          state.setState(CaptureMode.photo);
        } else {
          state.setState(CaptureMode.photo);
        }
      }
    } finally {
      _isCaptureActionInProgress = false;
    }
  }
}
