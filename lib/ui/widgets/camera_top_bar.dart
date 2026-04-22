import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CameraTopBar extends StatelessWidget {
  final VoidCallback onFlashToggle;
  final VoidCallback onSettingsTap;
  final String flashMode;

  const CameraTopBar({
    super.key,
    required this.onFlashToggle,
    required this.onSettingsTap,
    this.flashMode = 'off',
  });

  IconData _getFlashIcon() {
    switch (flashMode) {
      case 'on':
        return CupertinoIcons.bolt_fill;
      case 'auto':
        return CupertinoIcons.bolt_badge_a_fill;
      default:
        return CupertinoIcons.bolt_slash_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TopIcon(icon: _getFlashIcon(), onTap: onFlashToggle),
            // Indicador de resolución centrado
            const Text(
              '12M',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            _TopIcon(icon: CupertinoIcons.settings, onTap: onSettingsTap),
          ],
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TopIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
