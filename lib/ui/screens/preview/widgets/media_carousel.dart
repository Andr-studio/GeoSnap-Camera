import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaCarousel extends StatelessWidget {
  final PageController pageController;
  final List<String> sessionPaths;
  final List<bool> sessionIsVideo;
  final int activeIndex;
  final String currentPath;
  final bool currentIsVideo;
  final VideoPlayerController? videoController;
  final Future<void>? videoInitFuture;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onVideoTap;

  const MediaCarousel({
    super.key,
    required this.pageController,
    required this.sessionPaths,
    required this.sessionIsVideo,
    required this.activeIndex,
    required this.currentPath,
    required this.currentIsVideo,
    required this.videoController,
    required this.videoInitFuture,
    required this.onPageChanged,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sessionPaths.length <= 1) {
      return currentIsVideo ? _buildVideoView() : _buildImagePage(currentPath);
    }

    return PageView.builder(
      controller: pageController,
      itemCount: sessionPaths.length,
      onPageChanged: onPageChanged,
      itemBuilder: (BuildContext context, int index) {
        final String path = sessionPaths[index];
        final bool isVideo = sessionIsVideo[index];
        if (isVideo) {
          return index == activeIndex
              ? _buildVideoView()
              : const _VideoPlaceholder();
        }
        return _buildImagePage(path);
      },
    );
  }

  Widget _buildImagePage(String path) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Text(
              'No se pudo cargar la imagen',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final VideoPlayerController? controller = videoController;
    if (controller == null) {
      return const Center(
        child: Text(
          'No se pudo cargar el video',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder<void>(
      future: videoInitFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }
        if (snapshot.hasError || !controller.value.isInitialized) {
          return const Center(
            child: Text(
              'No se pudo cargar el video',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return GestureDetector(
          onTap: onVideoTap,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        );
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          CupertinoIcons.play_circle,
          color: Colors.white38,
          size: 64,
        ),
      ),
    );
  }
}
