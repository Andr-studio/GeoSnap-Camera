import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

class CameraTopControlsRow extends StatelessWidget {
  final IconData flashIcon;
  final String aspectRatio;
  final String resolutionLabel;
  final bool gpsReady;
  final double iconRotationTurns;
  final VoidCallback onFlashTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback? onResolutionTap;
  final VoidCallback onSettingsTap;

  const CameraTopControlsRow({
    super.key,
    required this.flashIcon,
    required this.aspectRatio,
    required this.resolutionLabel,
    required this.gpsReady,
    required this.iconRotationTurns,
    required this.onFlashTap,
    required this.onAspectRatioTap,
    required this.onResolutionTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        _TopIcon(
          icon: flashIcon,
          onTap: onFlashTap,
          size: 42,
          iconSize: 22,
          rotationTurns: iconRotationTurns,
        ),
        const SizedBox(width: 16),
        _AspectRatioButton(
          aspectRatio: aspectRatio,
          rotationTurns: iconRotationTurns,
          onTap: onAspectRatioTap,
        ),
        const SizedBox(width: 16),
        _ResolutionButton(
          label: resolutionLabel,
          rotationTurns: iconRotationTurns,
          onTap: onResolutionTap,
        ),
        const SizedBox(width: 16),
        _GpsStatusIcon(
          ready: gpsReady,
          onTap: onSettingsTap,
          size: 42,
          iconSize: 22,
          rotationTurns: iconRotationTurns,
        ),
      ],
    );
  }
}

class _AspectRatioButton extends StatelessWidget {
  final String aspectRatio;
  final double rotationTurns;
  final VoidCallback onTap;

  const _AspectRatioButton({
    required this.aspectRatio,
    required this.rotationTurns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        turns: rotationTurns,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.5),
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
    );
  }
}

class _ResolutionButton extends StatelessWidget {
  final String label;
  final double rotationTurns;
  final VoidCallback? onTap;

  const _ResolutionButton({
    required this.label,
    required this.rotationTurns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedRotation(
        turns: rotationTurns,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _GpsStatusIcon extends StatelessWidget {
  final bool ready;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final double rotationTurns;

  const _GpsStatusIcon({
    required this.ready,
    this.onTap,
    this.size = 42,
    this.iconSize = 22,
    this.rotationTurns = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = ready
        ? AppColors.gpsReady
        : AppColors.gpsUnavailable;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.20),
              border: Border.all(color: statusColor, width: 1.8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: statusColor.withValues(alpha: ready ? 0.38 : 0.26),
                  blurRadius: ready ? 14 : 10,
                  spreadRadius: ready ? 1 : 0,
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: rotationTurns,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Icon(
                ready ? CupertinoIcons.location_solid : CupertinoIcons.location,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final double rotationTurns;

  const _TopIcon({
    required this.icon,
    this.onTap,
    this.size = 32,
    this.iconSize = 20,
    this.rotationTurns = 0.0,
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
          child: AnimatedRotation(
            turns: rotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
