import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

import 'zoom_ruler.dart';

class ZoomCollapsedView extends StatelessWidget {
  final List<double> displayStops;
  final String Function(double displayZoom) labelForStop;
  final double Function(double displayZoom) normalizedZoomForStop;
  final bool Function(double displayZoom) isStopSelected;
  final double iconRotationTurns;
  final ValueChanged<double> onZoomSelected;

  const ZoomCollapsedView({
    super.key,
    required this.displayStops,
    required this.labelForStop,
    required this.normalizedZoomForStop,
    required this.isStopSelected,
    required this.iconRotationTurns,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const ValueKey<String>('collapsed'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: displayStops.map((double displayZoom) {
            return _ZoomStopButton(
              label: labelForStop(displayZoom),
              normalizedZoom: normalizedZoomForStop(displayZoom),
              selected: isStopSelected(displayZoom),
              iconRotationTurns: iconRotationTurns,
              onZoomSelected: onZoomSelected,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ZoomExpandedView extends StatelessWidget {
  final bool compact;
  final double currentZoom;
  final String zoomLabel;
  final List<double> displayStops;
  final String Function(double displayZoom) labelForStop;
  final double Function(double displayZoom) normalizedZoomForStop;
  final bool Function(double displayZoom) isStopSelected;
  final double iconRotationTurns;
  final ValueChanged<double> onZoomSelected;

  const ZoomExpandedView({
    super.key,
    required this.compact,
    required this.currentZoom,
    required this.zoomLabel,
    required this.displayStops,
    required this.labelForStop,
    required this.normalizedZoomForStop,
    required this.isStopSelected,
    required this.iconRotationTurns,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('expanded'),
      height: compact ? 96 : 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedRotation(
              turns: iconRotationTurns,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Text(
                zoomLabel,
                style: TextStyle(
                  color: AppColors.zoomGold,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          SizedBox(
            height: compact ? 20 : 26,
            width: double.infinity,
            child: ClipRect(
              child: CustomPaint(painter: ZoomRuler(zoom: currentZoom)),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            height: compact ? 34 : 38,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: displayStops.map((double displayZoom) {
                    return _ExpandedZoomStopButton(
                      label: labelForStop(displayZoom),
                      normalizedZoom: normalizedZoomForStop(displayZoom),
                      compact: compact,
                      selected: isStopSelected(displayZoom),
                      iconRotationTurns: iconRotationTurns,
                      onZoomSelected: onZoomSelected,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomStopButton extends StatelessWidget {
  final String label;
  final double normalizedZoom;
  final bool selected;
  final double iconRotationTurns;
  final ValueChanged<double> onZoomSelected;

  const _ZoomStopButton({
    required this.label,
    required this.normalizedZoom,
    required this.selected,
    required this.iconRotationTurns,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onZoomSelected(normalizedZoom);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedRotation(
            turns: iconRotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedZoomStopButton extends StatelessWidget {
  final String label;
  final double normalizedZoom;
  final bool compact;
  final bool selected;
  final double iconRotationTurns;
  final ValueChanged<double> onZoomSelected;

  const _ExpandedZoomStopButton({
    required this.label,
    required this.normalizedZoom,
    required this.compact,
    required this.selected,
    required this.iconRotationTurns,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onZoomSelected(normalizedZoom);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 15),
        child: AnimatedRotation(
          turns: iconRotationTurns,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.zoomGold : Colors.white,
              fontSize: compact ? 14 : 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
