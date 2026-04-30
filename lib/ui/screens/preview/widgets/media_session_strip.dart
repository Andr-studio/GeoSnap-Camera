import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MediaSessionStrip extends StatelessWidget {
  final List<String> sessionPaths;
  final List<bool> sessionIsVideo;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  const MediaSessionStrip({
    super.key,
    required this.sessionPaths,
    required this.sessionIsVideo,
    required this.activeIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: sessionPaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final bool isActive = index == activeIndex;
          final bool isVideo = sessionIsVideo[index];
          final String path = sessionPaths[index];

          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white24,
                  width: isActive ? 2.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (!isVideo)
                      Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(color: Colors.white12);
                        },
                      )
                    else
                      Container(color: Colors.black54),
                    if (isVideo)
                      const Center(
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
