import 'package:flutter/material.dart';

import 'focus_exposure_overlay.dart';

typedef PreviewTapDownCallback =
    void Function(TapDownDetails details, Size previewSize);

class CameraPreviewOverlay extends StatelessWidget {
  final PageController modePageController;
  final int modeCount;
  final ValueChanged<int> onModePageChanged;
  final PreviewTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final GestureTapCancelCallback onTapCancel;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;
  final Offset? focusPoint;
  final bool focusLocked;
  final bool focusVisible;
  final bool exposureVisible;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  const CameraPreviewOverlay({
    super.key,
    required this.modePageController,
    required this.modeCount,
    required this.onModePageChanged,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.focusPoint,
    required this.focusLocked,
    required this.focusVisible,
    required this.exposureVisible,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      bottom: 240,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: modePageController,
              itemCount: modeCount,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: onModePageChanged,
              itemBuilder: (BuildContext context, int index) {
                return Container(color: Colors.transparent);
              },
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size previewSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (TapDownDetails details) {
                    onTapDown(details, previewSize);
                  },
                  onTapUp: onTapUp,
                  onTapCancel: onTapCancel,
                  onScaleStart: onScaleStart,
                  onScaleUpdate: onScaleUpdate,
                  onScaleEnd: onScaleEnd,
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          Positioned.fill(
            child: FocusExposureOverlay(
              point: focusPoint,
              locked: focusLocked,
              visible: focusVisible,
              exposureVisible: exposureVisible,
              brightness: brightness,
              onBrightnessChanged: onBrightnessChanged,
            ),
          ),
        ],
      ),
    );
  }
}
