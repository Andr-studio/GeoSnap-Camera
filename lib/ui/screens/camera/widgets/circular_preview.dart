import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CircularPreview extends StatelessWidget {
  final VoidCallback onTap;
  final String? filePath;
  final bool isVideo;
  final bool isProcessing;
  final double iconRotationTurns;

  const CircularPreview({
    super.key,
    required this.onTap,
    this.filePath,
    this.isVideo = false,
    this.isProcessing = false,
    this.iconRotationTurns = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasMedia =
        !isProcessing &&
        filePath != null &&
        filePath!.isNotEmpty &&
        File(filePath!).existsSync();

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: ClipOval(
          child: AnimatedRotation(
            turns: iconRotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: isProcessing
                ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 11,
                      color: Colors.white70,
                    ),
                  )
                : hasMedia
                ? Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (!isVideo)
                        Image.file(
                          File(filePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      else
                        Container(color: Colors.black45),
                      if (isVideo)
                        const Center(
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  )
                : const Icon(CupertinoIcons.photo, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
