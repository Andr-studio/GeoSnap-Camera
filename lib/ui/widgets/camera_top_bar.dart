import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  bool _isSelected(String mode) {
    if (mode == 'on') {
      return flashMode == 'on' || flashMode == 'always';
    }
    return flashMode == mode;
  }

  Widget _flashOption({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 44,
        child: Center(
          child: Icon(
            icon,
            color: selected ? const Color(0xFFFFD54F) : Colors.white,
            size: 24,
          ),
        ),
      ),
    );
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
                  colors: [
                    Colors.black45,
                    Colors.transparent,
                  ],
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
                      children: [
                        _TopIcon(
                          icon: _getFlashIcon(),
                          onTap: onFlashTap,
                          size: 42,
                          iconSize: 22,
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: onAspectRatioTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              aspectRatio,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: onResolutionTap,
                          child: Text(
                            resolutionLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _TopIcon(
                          icon: CupertinoIcons.settings,
                          onTap: onSettingsTap,
                          size: 42,
                          iconSize: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: topRowHeight + flashMenuTopGap,
                  child: IgnorePointer(
                    ignoring: !flashMenuOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: flashMenuOpen ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 180),
                        offset: flashMenuOpen
                            ? Offset.zero
                            : const Offset(0, -0.08),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          height: flashMenuHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A3F47),
                            borderRadius: BorderRadius.circular(28),
                          ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _flashOption(
                              icon: CupertinoIcons.bolt_slash_fill,
                              selected: _isSelected('none'),
                              onTap: onFlashOffTap,
                            ),
                            if (!isRecordingVideo)
                              _flashOption(
                                icon: CupertinoIcons.bolt_badge_a_fill,
                                selected: _isSelected('auto'),
                                onTap: onFlashAutoTap,
                              ),
                            _flashOption(
                              icon: CupertinoIcons.bolt_fill,
                              selected: _isSelected('on'),
                                onTap: onFlashOnTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  const _TopIcon({
    required this.icon,
    this.onTap,
    this.size = 32,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
