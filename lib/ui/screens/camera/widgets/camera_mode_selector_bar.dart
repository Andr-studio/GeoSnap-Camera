import 'package:flutter/material.dart';

import 'camera_mode_selector.dart';

class CameraModeSelectorBar extends StatelessWidget {
  final String selectedAspectRatio;
  final ValueNotifier<int> selectedModeNotifier;
  final PageController pageController;
  final List<String> modes;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<int> onModeTap;

  const CameraModeSelectorBar({
    super.key,
    required this.selectedAspectRatio,
    required this.selectedModeNotifier,
    required this.pageController,
    required this.modes,
    required this.onModeChanged,
    required this.onModeTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget selector = ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: <double>[0.0, 0.35, 0.65, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ValueListenableBuilder<int>(
        valueListenable: selectedModeNotifier,
        builder: (BuildContext context, int index, Widget? child) {
          return CameraModeSelector(
            modes: modes,
            selectedIndex: index,
            pageController: pageController,
            onModeChanged: onModeChanged,
            onModeTap: onModeTap,
          );
        },
      ),
    );

    if (selectedAspectRatio == '9:16') {
      return Container(
        color: Colors.black,
        padding: EdgeInsets.only(
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom + 6,
        ),
        child: selector,
      );
    }

    return selector;
  }
}
