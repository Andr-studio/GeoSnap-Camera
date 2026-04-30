import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

import 'circular_icon_button.dart';
import 'circular_preview.dart';
import 'shutter_button.dart';

class CameraCaptureBar extends StatelessWidget {
  final CameraState cameraState;
  final ValueNotifier<int> selectedModeNotifier;
  final int videoModeIndex;
  final String? lastCapturePath;
  final bool lastCaptureIsVideo;
  final bool isWatermarkProcessing;
  final double iconRotationTurns;
  final VoidCallback onLastCaptureTap;
  final VoidCallback onSwitchCameraTap;
  final VoidCallback onShutterTap;

  const CameraCaptureBar({
    super.key,
    required this.cameraState,
    required this.selectedModeNotifier,
    required this.videoModeIndex,
    required this.lastCapturePath,
    required this.lastCaptureIsVideo,
    required this.isWatermarkProcessing,
    required this.iconRotationTurns,
    required this.onLastCaptureTap,
    required this.onSwitchCameraTap,
    required this.onShutterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          CircularPreview(
            onTap: onLastCaptureTap,
            filePath: lastCapturePath,
            isVideo: lastCaptureIsVideo,
            isProcessing: isWatermarkProcessing,
            iconRotationTurns: iconRotationTurns,
          ),
          ValueListenableBuilder<int>(
            valueListenable: selectedModeNotifier,
            builder: (BuildContext context, int index, Widget? child) {
              return ShutterButton(
                key: ValueKey<String>(
                  'shutter-$index-${cameraState.runtimeType}',
                ),
                isVideoMode: index == videoModeIndex,
                isRecording: cameraState is VideoRecordingCameraState,
                onTap: onShutterTap,
              );
            },
          ),
          CircularIconButton(
            icon: Icons.cached_rounded,
            rotationTurns: iconRotationTurns,
            onTap: onSwitchCameraTap,
          ),
        ],
      ),
    );
  }
}
