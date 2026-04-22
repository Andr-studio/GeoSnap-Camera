import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  final bool isVideoMode;
  final bool isRecording;
  final VoidCallback onTap;

  const ShutterButton({
    super.key,
    required this.isVideoMode,
    this.isRecording = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isVideoMode ? 3 : 5,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isVideoMode ? (isRecording ? Colors.red : Colors.red) : Colors.white,
            borderRadius: BorderRadius.circular(
              isRecording ? 8 : 40,
            ),
          ),
          margin: EdgeInsets.all(isRecording ? 15 : 0),
        ),
      ),
    );
  }
}
