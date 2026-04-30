import 'package:flutter/material.dart';

class CircularIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double rotationTurns;

  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.rotationTurns = 0.0,
  });

  @override
  State<CircularIconButton> createState() => CircularIconButtonState();
}

class CircularIconButtonState extends State<CircularIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: RotationTransition(
          turns: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
          ),
          child: AnimatedRotation(
            turns: widget.rotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(widget.icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
