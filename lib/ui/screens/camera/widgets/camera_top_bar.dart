import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

import 'camera_flash_menu.dart';
import 'camera_top_controls_row.dart';

class CameraTopBar extends StatelessWidget {
  final VoidCallback onFlashTap;
  final VoidCallback onFlashOffTap;
  final VoidCallback onFlashAutoTap;
  final VoidCallback onFlashOnTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback? onResolutionTap;
  final String flashMode;
  final bool flashMenuOpen;
  final bool isRecordingVideo;
  final String aspectRatio;
  final String resolutionLabel;
  final bool solidBlackBackground;
  final bool gpsReady;
  final String? recordingTimeLabel;
  final double iconRotationTurns;

  const CameraTopBar({
    super.key,
    required this.onFlashTap,
    required this.onFlashOffTap,
    required this.onFlashAutoTap,
    required this.onFlashOnTap,
    required this.onSettingsTap,
    required this.onAspectRatioTap,
    this.onResolutionTap,
    this.flashMode = 'off',
    this.flashMenuOpen = false,
    this.isRecordingVideo = false,
    this.aspectRatio = '3:4',
    this.resolutionLabel = '--M',
    this.solidBlackBackground = false,
    this.gpsReady = false,
    this.recordingTimeLabel,
    this.iconRotationTurns = 0.0,
  });

  IconData _getFlashIcon() {
    switch (flashMode) {
      case 'on':
      case 'always':
        return CupertinoIcons.bolt_fill;
      case 'auto':
        return CupertinoIcons.bolt_badge_a_fill;
      default:
        return CupertinoIcons.bolt_slash_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets contentPadding = solidBlackBackground
        ? const EdgeInsets.fromLTRB(0, 2, 0, 4)
        : const EdgeInsets.fromLTRB(0, 10, 0, 10);
    const double horizontalContentInset = 20;
    const double topRowHeight = 42;
    const double flashMenuTopGap = 8;
    const double flashMenuHeight = 50;
    final double interactiveHeight = flashMenuOpen
        ? topRowHeight + flashMenuTopGap + flashMenuHeight
        : topRowHeight;

    final bool isFullRatio = aspectRatio == 'Full';
    final double statusBarTopInset = MediaQuery.of(context).padding.top;
    const BoxDecoration outerDecoration = BoxDecoration(
      color: Colors.transparent,
    );

    final BoxDecoration topRowDecoration = solidBlackBackground
        ? const BoxDecoration(color: Colors.black)
        : isFullRatio
        ? const BoxDecoration(color: Colors.transparent)
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black45, Colors.transparent],
            ),
          );

    return Container(
      decoration: outerDecoration,
      child: Stack(
        children: [
          if (solidBlackBackground)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: statusBarTopInset + contentPadding.top + topRowHeight,
                color: Colors.black,
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: contentPadding,
              child: SizedBox(
                height: interactiveHeight,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: topRowHeight,
                      decoration: topRowDecoration,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: horizontalContentInset,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: CameraTopControlsRow(
                                flashIcon: _getFlashIcon(),
                                aspectRatio: aspectRatio,
                                resolutionLabel: resolutionLabel,
                                gpsReady: gpsReady,
                                iconRotationTurns: iconRotationTurns,
                                onFlashTap: onFlashTap,
                                onAspectRatioTap: onAspectRatioTap,
                                onResolutionTap: onResolutionTap,
                                onSettingsTap: onSettingsTap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: horizontalContentInset,
                      height: topRowHeight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: recordingTimeLabel == null ? 0 : 1,
                        child: recordingTimeLabel == null
                            ? const SizedBox.shrink()
                            : _RecordingTimerPill(label: recordingTimeLabel!),
                      ),
                    ),
                    Positioned(
                      top: topRowHeight + flashMenuTopGap,
                      child: CameraFlashMenu(
                        open: flashMenuOpen,
                        flashMode: flashMode,
                        isRecordingVideo: isRecordingVideo,
                        rotationTurns: iconRotationTurns,
                        onFlashOffTap: onFlashOffTap,
                        onFlashAutoTap: onFlashAutoTap,
                        onFlashOnTap: onFlashOnTap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingTimerPill extends StatelessWidget {
  final String label;

  const _RecordingTimerPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.destructive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
