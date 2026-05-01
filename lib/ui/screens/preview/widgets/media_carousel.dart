import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaCarousel extends StatefulWidget {
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
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;

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
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  bool _isZoomed = false;

  void _handleZoomChanged(bool isZoomed) {
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionPaths.length <= 1) {
      return _buildZoomable(
        child: widget.currentIsVideo ? _buildVideoView() : _buildImagePage(widget.currentPath),
      );
    }

    return PageView.builder(
      controller: widget.pageController,
      physics: _isZoomed
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: widget.sessionPaths.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (BuildContext context, int index) {
        final String path = widget.sessionPaths[index];
        final bool isVideo = widget.sessionIsVideo[index];
        if (isVideo) {
          return index == widget.activeIndex
              ? _buildZoomable(child: _buildVideoView())
              : const _VideoPlaceholder();
        }
        return _buildZoomable(child: _buildImagePage(path));
      },
    );
  }

  Widget _buildZoomable({required Widget child}) {
    return _ZoomableMediaItem(
      onVerticalDragUpdate: widget.onVerticalDragUpdate,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onZoomChanged: _handleZoomChanged,
      child: child,
    );
  }

  Widget _buildImagePage(String path) {
    return Center(
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
    );
  }

  Widget _buildVideoView() {
    final VideoPlayerController? controller = widget.videoController;
    if (controller == null) {
      return const Center(
        child: Text(
          'No se pudo cargar el video',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder<void>(
      future: widget.videoInitFuture,
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
          onTap: widget.onVideoTap,
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

class _ZoomableMediaItem extends StatefulWidget {
  final Widget child;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomableMediaItem({
    required this.child,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onZoomChanged,
  });

  @override
  State<_ZoomableMediaItem> createState() => _ZoomableMediaItemState();
}

class _ZoomableMediaItemState extends State<_ZoomableMediaItem>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onScaleChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  void _onScaleChanged() {
    final bool isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    widget.onZoomChanged?.call(isZoomed);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onScaleChanged);
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double targetScale = currentScale > 1.5 ? 1.0 : 3.0;

    if (targetScale == 1.0) {
      _animateToMatrix(Matrix4.identity());
      return;
    }

    final Offset tapPosition = details.localPosition;
    final double x = -tapPosition.dx * (targetScale - 1);
    final double y = -tapPosition.dy * (targetScale - 1);
    final Matrix4 targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(2, 2, 1.0)
      ..setEntry(0, 3, x)
      ..setEntry(1, 3, y);

    _animateToMatrix(targetMatrix);
  }

  void _animateToMatrix(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 6.0,
        panEnabled: true,
        scaleEnabled: true,
        onInteractionUpdate: (ScaleUpdateDetails details) {
          if (_transformationController.value.getMaxScaleOnAxis() <= 1.01) {
            if (details.scale == 1.0 && details.pointerCount == 1) {
              final double dy = details.focalPointDelta.dy;
              if (dy != 0) {
                widget.onVerticalDragUpdate?.call(DragUpdateDetails(
                  globalPosition: details.focalPoint,
                  delta: Offset(0, dy),
                  primaryDelta: dy,
                ));
              }
            }
          }
        },
        onInteractionEnd: (ScaleEndDetails details) {
          if (_transformationController.value.getMaxScaleOnAxis() <= 1.01) {
            final double vy = details.velocity.pixelsPerSecond.dy;
            widget.onVerticalDragEnd?.call(DragEndDetails(
              velocity: Velocity(pixelsPerSecond: Offset(0, vy)),
              primaryVelocity: vy,
            ));
          }
        },
        child: widget.child,
      ),
    );
  }
}
