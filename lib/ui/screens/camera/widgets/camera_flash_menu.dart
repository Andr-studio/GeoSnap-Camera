import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

class CameraFlashMenu extends StatelessWidget {
  final bool open;
  final String flashMode;
  final bool isRecordingVideo;
  final double rotationTurns;
  final VoidCallback onFlashOffTap;
  final VoidCallback onFlashAutoTap;
  final VoidCallback onFlashOnTap;

  const CameraFlashMenu({
    super.key,
    required this.open,
    required this.flashMode,
    required this.isRecordingVideo,
    required this.rotationTurns,
    required this.onFlashOffTap,
    required this.onFlashAutoTap,
    required this.onFlashOnTap,
  });

  bool _isSelected(String mode) {
    if (mode == 'on') {
      return flashMode == 'on' || flashMode == 'always';
    }
    return flashMode == mode;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: open ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          offset: open ? Offset.zero : const Offset(0, -0.08),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3F47),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _FlashOption(
                  icon: CupertinoIcons.bolt_slash_fill,
                  selected: _isSelected('none'),
                  onTap: onFlashOffTap,
                  rotationTurns: rotationTurns,
                ),
                if (!isRecordingVideo)
                  _FlashOption(
                    icon: CupertinoIcons.bolt_badge_a_fill,
                    selected: _isSelected('auto'),
                    onTap: onFlashAutoTap,
                    rotationTurns: rotationTurns,
                  ),
                _FlashOption(
                  icon: CupertinoIcons.bolt_fill,
                  selected: _isSelected('on'),
                  onTap: onFlashOnTap,
                  rotationTurns: rotationTurns,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashOption extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double rotationTurns;

  const _FlashOption({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.rotationTurns,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 44,
        child: Center(
          child: AnimatedRotation(
            turns: rotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(
              icon,
              color: selected ? AppColors.focusGold : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
