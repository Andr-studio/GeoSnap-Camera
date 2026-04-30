import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'system_gallery_launcher.dart';
import 'widgets/media_action_bar.dart';
import 'widgets/media_carousel.dart';
import 'widgets/media_session_strip.dart';
import 'widgets/video_control_overlay.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;
  final List<String> sessionPaths;
  final List<bool> sessionIsVideo;

  const MediaPreviewScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
    this.sessionPaths = const <String>[],
    this.sessionIsVideo = const <bool>[],
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  bool _isPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  Timer? _progressTimer;

  late int _activeIndex;
  late String _currentPath;
  late bool _currentIsVideo;
  late PageController _pageController;

  bool _chromeVisible = true;
  Timer? _autohideTimer;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.mediaPath;
    _currentIsVideo = widget.isVideo;

    final int index = widget.sessionPaths.indexOf(widget.mediaPath);
    _activeIndex = index >= 0
        ? index
        : (widget.sessionPaths.isNotEmpty
              ? widget.sessionPaths.length - 1
              : -1);

    _pageController = PageController(
      initialPage: _activeIndex >= 0 ? _activeIndex : 0,
    );

    _initMedia(_currentPath, _currentIsVideo);
    _scheduleAutohide();
  }

  @override
  void dispose() {
    _autohideTimer?.cancel();
    _progressTimer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initMedia(String path, bool isVideo) {
    _disposeVideoController();
    if (!isVideo) return;

    final VideoPlayerController controller = VideoPlayerController.file(
      File(path),
    );
    _videoController = controller;
    _videoInitFuture = controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      _videoDuration = controller.value.duration;
      setState(() {
        _isPlaying = true;
      });
      controller.play();
      _startProgressTimer();
    });
  }

  void _disposeVideoController() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _videoController?.dispose();
    _videoController = null;
    _videoInitFuture = null;
    _videoPosition = Duration.zero;
    _videoDuration = Duration.zero;
    _isPlaying = false;
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final VideoPlayerController? controller = _videoController;
      if (controller == null || !mounted) return;
      setState(() {
        _videoPosition = controller.value.position;
        _isPlaying = controller.value.isPlaying;
      });
    });
  }

  void _scheduleAutohide() {
    _autohideTimer?.cancel();
    _autohideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _chromeVisible = false;
        });
      }
    });
  }

  void _toggleChrome() {
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
    if (_chromeVisible) {
      _scheduleAutohide();
    }
  }

  void _selectSession(int index) {
    if (index < 0 || index >= widget.sessionPaths.length) return;
    if (index == _activeIndex) return;

    setState(() {
      _activeIndex = index;
      _currentPath = widget.sessionPaths[index];
      _currentIsVideo = widget.sessionIsVideo[index];
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    _initMedia(_currentPath, _currentIsVideo);
    _scheduleAutohide();
  }

  void _handlePageChanged(int index) {
    final String path = widget.sessionPaths[index];
    final bool isVideo = widget.sessionIsVideo[index];
    setState(() {
      _activeIndex = index;
      _currentPath = path;
      _currentIsVideo = isVideo;
    });
    _initMedia(path, isVideo);
    _scheduleAutohide();
  }

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(_currentPath)]),
    );
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Eliminar'),
        content: Text(
          _currentIsVideo
              ? 'Eliminar este video? Esta accion no se puede deshacer.'
              : 'Eliminar esta foto? Esta accion no se puede deshacer.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final File file = File(_currentPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openSystemGallery() async {
    await SystemGalleryLauncher.open(context);
  }

  void _togglePlayPause() {
    final VideoPlayerController? controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.selectionClick();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _scheduleAutohide();
    setState(() {
      _isPlaying = controller.value.isPlaying;
    });
  }

  void _seekVideo(Duration position) {
    _videoController?.seekTo(position);
    _scheduleAutohide();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final bool hasSession = widget.sessionPaths.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: MediaCarousel(
                pageController: _pageController,
                sessionPaths: widget.sessionPaths,
                sessionIsVideo: widget.sessionIsVideo,
                activeIndex: _activeIndex,
                currentPath: _currentPath,
                currentIsVideo: _currentIsVideo,
                videoController: _videoController,
                videoInitFuture: _videoInitFuture,
                onPageChanged: _handlePageChanged,
                onVideoTap: _togglePlayPause,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _chromeVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 260),
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: _buildBottomChrome(bottomPadding, hasSession),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: AnimatedOpacity(
        opacity: _chromeVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 260),
        child: IgnorePointer(
          ignoring: !_chromeVisible,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: IconButton(
                icon: const Icon(
                  CupertinoIcons.chevron_back,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        AnimatedOpacity(
          opacity: _chromeVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 260),
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: IconButton(
                    tooltip: 'Abrir galeria',
                    icon: const Icon(
                      CupertinoIcons.photo_on_rectangle,
                      color: Colors.white,
                    ),
                    onPressed: _openSystemGallery,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomChrome(double bottomPadding, bool hasSession) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                const Color.fromARGB(0, 0, 0, 0).withValues(alpha: 0.30),
                const Color.fromARGB(0, 0, 0, 0).withValues(alpha: 0.52),
              ],
              stops: const <double>[0.0, 0.40, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_currentIsVideo)
                  VideoControlOverlay(
                    isPlaying: _isPlaying,
                    position: _videoPosition,
                    duration: _videoDuration,
                    onTogglePlay: _togglePlayPause,
                    onSeek: _seekVideo,
                  ),
                if (hasSession)
                  MediaSessionStrip(
                    sessionPaths: widget.sessionPaths,
                    sessionIsVideo: widget.sessionIsVideo,
                    activeIndex: _activeIndex,
                    onSelected: _selectSession,
                  ),
                const SizedBox(height: 12),
                MediaActionBar(
                  isVideo: _currentIsVideo,
                  isPlaying: _isPlaying,
                  onShare: _share,
                  onTogglePlay: _togglePlayPause,
                  onOpenGallery: _openSystemGallery,
                  onDelete: _confirmDelete,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
