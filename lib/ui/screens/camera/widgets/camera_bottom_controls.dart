import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

import 'camera_capture_bar.dart';
import 'camera_mode_selector_bar.dart';
import 'zoom_selector.dart';

class CameraBottomControls extends StatelessWidget {
  final CameraState cameraState;
  final String selectedAspectRatio;
  final SensorConfig sensorConfig;
  final ValueNotifier<int> selectedModeNotifier;
  final ValueNotifier<int> pinchExpandNotifier;
  final PageController bottomPageController;
  final List<String> modes;
  final int videoModeIndex;
  final String? lastCapturePath;
  final bool lastCaptureIsVideo;
  final bool isWatermarkProcessing;
  final double iconRotationTurns;
  final VoidCallback onLastCaptureTap;
  final VoidCallback onSwitchCameraTap;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<int> onModeTap;
  final VoidCallback onShutterTap;

  const CameraBottomControls({
    super.key,
    required this.cameraState,
    required this.selectedAspectRatio,
    required this.sensorConfig,
    required this.selectedModeNotifier,
    required this.pinchExpandNotifier,
    required this.bottomPageController,
    required this.modes,
    required this.videoModeIndex,
    required this.lastCapturePath,
    required this.lastCaptureIsVideo,
    required this.isWatermarkProcessing,
    required this.iconRotationTurns,
    required this.onLastCaptureTap,
    required this.onSwitchCameraTap,
    required this.onModeChanged,
    required this.onModeTap,
    required this.onShutterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        bottom: selectedAspectRatio != '9:16',
        child: Container(
          height: selectedAspectRatio == '9:16'
              ? 260.0 + MediaQuery.of(context).padding.bottom
              : 252.0,
          color: _isBottomPanelTransparent()
              ? Colors.transparent
              : Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ZoomSelector(
                sensorConfig: sensorConfig,
                pinchExpandNotifier: pinchExpandNotifier,
                compactMode: selectedAspectRatio == '9:16',
                iconRotationTurns: iconRotationTurns,
              ),
              CameraCaptureBar(
                cameraState: cameraState,
                selectedModeNotifier: selectedModeNotifier,
                videoModeIndex: videoModeIndex,
                lastCapturePath: lastCapturePath,
                lastCaptureIsVideo: lastCaptureIsVideo,
                isWatermarkProcessing: isWatermarkProcessing,
                iconRotationTurns: iconRotationTurns,
                onLastCaptureTap: onLastCaptureTap,
                onSwitchCameraTap: onSwitchCameraTap,
                onShutterTap: onShutterTap,
              ),
              CameraModeSelectorBar(
                selectedAspectRatio: selectedAspectRatio,
                selectedModeNotifier: selectedModeNotifier,
                pageController: bottomPageController,
                modes: modes,
                onModeChanged: onModeChanged,
                onModeTap: onModeTap,
              ),
              SizedBox(height: selectedAspectRatio == '9:16' ? 0 : 5),
            ],
          ),
        ),
      ),
    );
  }

  bool _isBottomPanelTransparent() {
    return selectedAspectRatio == 'Full' || selectedAspectRatio == '9:16';
  }
}
