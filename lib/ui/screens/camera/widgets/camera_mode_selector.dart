import 'package:flutter/material.dart';

class CameraModeSelector extends StatelessWidget {
  final List<String> modes;
  final int selectedIndex;
  final Function(int) onModeChanged;
  final PageController pageController;
  final Function(int) onModeTap;

  const CameraModeSelector({
    super.key,
    required this.modes,
    required this.selectedIndex,
    required this.onModeChanged,
    required this.pageController,
    required this.onModeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: PageView.builder(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: onModeChanged,
        itemCount: modes.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onModeTap(index),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Text(modes[index].toUpperCase()),
              ),
            ),
          );
        },
      ),
    );
  }
}
