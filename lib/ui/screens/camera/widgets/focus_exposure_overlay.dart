import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

class FocusExposureOverlay extends StatelessWidget {
  final Offset? point;
  final bool locked;
  final bool visible;
  final bool exposureVisible;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  const FocusExposureOverlay({
    super.key,
    required this.point,
    required this.locked,
    required this.visible,
    required this.exposureVisible,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Offset? focusPoint = point;
    if (focusPoint == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double x = focusPoint.dx.clamp(54.0, constraints.maxWidth - 96.0);
        final double y = focusPoint.dy.clamp(
          54.0,
          constraints.maxHeight - 96.0,
        );
        final bool sliderOnRight = x < constraints.maxWidth - 122;
        final double sliderLeft = sliderOnRight ? x + 42 : x - 104;
        final double sliderTop = (y - 84).clamp(
          12.0,
          constraints.maxHeight - 188.0,
        );

        return IgnorePointer(
          ignoring: !exposureVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: x - 31,
                  top: y - 31,
                  child: _FocusRing(locked: locked),
                ),
                Positioned(
                  left: sliderLeft,
                  top: sliderTop,
                  child: IgnorePointer(
                    ignoring: !exposureVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: exposureVisible ? 1 : 0,
                      child: _ExposureSlider(
                        value: brightness,
                        locked: locked,
                        onChanged: onBrightnessChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FocusRing extends StatelessWidget {
  final bool locked;

  const _FocusRing({required this.locked});

  @override
  Widget build(BuildContext context) {
    final Color color = locked ? AppColors.focusGold : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.8),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 18),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: locked
              ? const Icon(
                  CupertinoIcons.lock_fill,
                  key: ValueKey<String>('locked'),
                  color: AppColors.focusGold,
                  size: 18,
                )
              : Container(
                  key: const ValueKey<String>('unlocked'),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExposureSlider extends StatelessWidget {
  final double value;
  final bool locked;
  final ValueChanged<double> onChanged;

  const _ExposureSlider({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = locked ? AppColors.focusGold : Colors.white;

    return Container(
      width: 48,
      height: 176,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Icon(CupertinoIcons.sun_max_fill, color: accent, size: 18),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.14),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
