import 'package:flutter/material.dart';

class CameraModeSelector extends StatefulWidget {
  final List<String> modes;
  final int selectedIndex;
  final Function(int) onModeChanged;

  const CameraModeSelector({
    super.key,
    required this.modes,
    required this.selectedIndex,
    required this.onModeChanged,
  });

  @override
  State<CameraModeSelector> createState() => _CameraModeSelectorState();
}

class _CameraModeSelectorState extends State<CameraModeSelector> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 👉 viewportFraction logra el efecto carrusel mostrando elementos contiguos
    _pageController = PageController(
      initialPage: widget.selectedIndex,
      viewportFraction: 0.22,
    );
  }

  @override
  void didUpdateWidget(covariant CameraModeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 👉 Sincroniza la animación si el índice cambia al deslizar la vista de cámara
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _pageController.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: widget.onModeChanged,
        itemCount: widget.modes.length,
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          return GestureDetector(
            onTap: () {
              // Tocar un texto lo lleva automáticamente al centro
              widget.onModeChanged(index);
            },
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
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Text(widget.modes[index].toUpperCase()),
              ),
            ),
          );
        },
      ),
    );
  }
}
