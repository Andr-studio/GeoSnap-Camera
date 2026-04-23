import 'dart:async';
import 'dart:io';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../widgets/shutter_button.dart';
import '../widgets/camera_top_bar.dart';
import '../widgets/camera_mode_selector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final List<String> _modes = ['Retrato', 'Imagen', 'Video'];
  late PageController _modePageController;
  late PageController _bottomPageController;
  final ValueNotifier<int> _selectedModeNotifier = ValueNotifier(1);
  final ValueNotifier<int> _pinchExpandNotifier = ValueNotifier(0);
  int _pendingCameraMode = 1;
  bool _isAppInBackground = false;
  bool _isFlashMenuOpen = false;
  bool _isCameraSwitchInProgress = false;
  DateTime? _lastSwipeCameraSwitchAt;
  bool _isSingleFingerSwipeTracking = false;
  double? _singleFingerSwipeStartY;
  double? _singleFingerSwipeLastY;
  double _cameraSwitchOverlayOpacity = 0.0;
  bool _isSyncing = false; // 👉 Controla la sincronización en espejo
  double _lastHapticPosition = 1.0; // 👉 Guarda la última posición que vibró
  String _selectedAspectRatio = '3:4';
  double _pinchLastScale = 1.0;
  String _resolutionLabel = '12M';
  bool _isDetectingPhotoSize = false;
  bool _didApplyBestPhotoSizeOnce = false;
  static const double _defaultMegapixels = 12.0;
  static const double _highResMegapixelsThreshold = 40.0;
  static const double _singleFingerSwipeDistanceThreshold = 70.0;
  static const double _singleFingerSwipeVelocityThreshold = 700.0;
  static const Duration _cameraSwitchSwipeCooldown = Duration(
    milliseconds: 700,
  );
  List<Size> _photoSizeOptions = <Size>[];
  int _selectedPhotoSizeIndex = -1;
  Size? _appliedPhotoSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _modePageController =
        PageController(initialPage: _selectedModeNotifier.value);
    _bottomPageController = PageController(
      initialPage: _selectedModeNotifier.value,
      viewportFraction: 0.22,
    );

    _lastHapticPosition = _selectedModeNotifier.value.toDouble();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _modePageController.dispose();
    _bottomPageController.dispose();
    _pinchExpandNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppInBackground = state != AppLifecycleState.resumed;
    });
  }

  Future<String> _getPath(String extension) async {
    final Directory extDir = await getTemporaryDirectory();
    final testDir = await Directory(
      p.join(extDir.path, 'GeoSnap'),
    ).create(recursive: true);
    return p.join(
      testDir.path,
      '${DateTime.now().millisecondsSinceEpoch}$extension',
    );
  }

  Future<void> _switchCamera(CameraState state) async {
    if (_isFlashMenuOpen && mounted) {
      setState(() {
        _isFlashMenuOpen = false;
      });
    }
    await state.switchCameraSensor();
    _appliedPhotoSize = null;
    await _loadPhotoSizes(resetSelection: true);
  }

  // 👉 Actualiza solo la Interfaz Visual al deslizar
  void _onPageChanged(int index) {
    if (index == _selectedModeNotifier.value) return;

    HapticFeedback.selectionClick();
    _selectedModeNotifier.value = index;
  }

  void _onModeTap(int index) {
    _modePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    _bottomPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  // 👉 Actualiza el Hardware SOLO cuando el deslizamiento termina
  void _applyCameraHardwareMode(CameraState state) {
    final int selectedIndex = _selectedModeNotifier.value;
    if (_pendingCameraMode == selectedIndex) return;
    _pendingCameraMode = selectedIndex;

    if (selectedIndex == 0 || selectedIndex == 1) {
      state.setState(CaptureMode.photo);
    } else if (selectedIndex == 2) {
      state.setState(CaptureMode.video);
    }
  }

  Future<void> _toggleAspectRatio(CameraState state) async {
    HapticFeedback.selectionClick();
    if (_isFlashMenuOpen && mounted) {
      setState(() {
        _isFlashMenuOpen = false;
      });
    }
    String nextAspectRatioLabel;
    CameraAspectRatios nextCameraAspectRatio;

    if (_selectedAspectRatio == '3:4') {
      nextAspectRatioLabel = '9:16';
      nextCameraAspectRatio = CameraAspectRatios.ratio_16_9;
    } else if (_selectedAspectRatio == '9:16') {
      nextAspectRatioLabel = '1:1';
      nextCameraAspectRatio = CameraAspectRatios.ratio_1_1;
    } else if (_selectedAspectRatio == '1:1') {
      nextAspectRatioLabel = 'Full';
      // En Camerawesome, el ratio "Full" no existe como tal, se usa 16:9 con preview fit.
      nextCameraAspectRatio = CameraAspectRatios.ratio_16_9;
    } else {
      nextAspectRatioLabel = '3:4';
      nextCameraAspectRatio = CameraAspectRatios.ratio_4_3;
    }

    if (mounted) {
      setState(() {
        _selectedAspectRatio = nextAspectRatioLabel;
      });
    }
    await state.sensorConfig.setAspectRatio(nextCameraAspectRatio);
    await _loadPhotoSizes(resetSelection: false);
  }

  double _toMegapixels(Size size) => (size.width * size.height) / 1000000;

  String _formatMegapixelsLabelFromSize(Size size) {
    return '${_toMegapixels(size).round()}M';
  }

  List<Size> _buildSortedUniquePhotoSizes(List<Size> sizes) {
    final Map<String, Size> uniqueByDimensions = <String, Size>{};
    for (final Size size in sizes) {
      if (size.width <= 0 || size.height <= 0) continue;
      final String key = '${size.width.round()}x${size.height.round()}';
      uniqueByDimensions[key] = size;
    }

    final List<Size> candidates = uniqueByDimensions.values.toList()
      ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));

    if (candidates.isEmpty) return <Size>[];

    final int baseIndex = _findDefaultPhotoSizeIndex(candidates);
    final Size baseSize = candidates[baseIndex];

    Size? highResSize;
    for (final Size size in candidates) {
      if (_toMegapixels(size) >= _highResMegapixelsThreshold) {
        highResSize = size;
      }
    }

    if (highResSize == null) {
      return <Size>[baseSize];
    }

    final bool sameSize = baseSize.width == highResSize.width &&
        baseSize.height == highResSize.height;
    if (sameSize) {
      return <Size>[baseSize];
    }

    return <Size>[baseSize, highResSize];
  }

  int _findDefaultPhotoSizeIndex(List<Size> options) {
    if (options.isEmpty) return -1;
    int bestIndex = 0;
    double bestDiff = (_toMegapixels(options[0]) - _defaultMegapixels).abs();
    for (int i = 1; i < options.length; i++) {
      final double currentMp = _toMegapixels(options[i]);
      final double bestMp = _toMegapixels(options[bestIndex]);
      final double diff = (currentMp - _defaultMegapixels).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
        continue;
      }
      if (diff == bestDiff &&
          currentMp <= _defaultMegapixels &&
          bestMp > _defaultMegapixels) {
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _loadPhotoSizes({required bool resetSelection}) async {
    if (_isDetectingPhotoSize) return;
    _isDetectingPhotoSize = true;

    try {
      final List<Size> options = _buildSortedUniquePhotoSizes(
        await CamerawesomePlugin.getSizes(),
      );
      if (options.isEmpty) {
        if (mounted) {
          setState(() {
            _photoSizeOptions = <Size>[];
            _selectedPhotoSizeIndex = -1;
            _resolutionLabel = '12M';
          });
        }
        return;
      }

      int nextIndex = _selectedPhotoSizeIndex;
      if (resetSelection ||
          nextIndex < 0 ||
          nextIndex >= options.length ||
          nextIndex >= _photoSizeOptions.length) {
        nextIndex = _findDefaultPhotoSizeIndex(options);
      } else {
        final Size current = _photoSizeOptions[_selectedPhotoSizeIndex];
        final int found = options.indexWhere(
          (s) => s.width == current.width && s.height == current.height,
        );
        nextIndex = found >= 0 ? found : _findDefaultPhotoSizeIndex(options);
      }

      _photoSizeOptions = options;
      _selectedPhotoSizeIndex = nextIndex;

      if (mounted) {
        setState(() {
          _resolutionLabel = _formatMegapixelsLabelFromSize(
            _photoSizeOptions[_selectedPhotoSizeIndex],
          );
        });
      }

      await _applySelectedPhotoSize();
    } catch (_) {
      // Keep fallback label when size list is unavailable on this device.
      if (mounted) {
        setState(() {
          _resolutionLabel = '12M';
        });
      }
    } finally {
      _isDetectingPhotoSize = false;
    }
  }

  Future<void> _applySelectedPhotoSize() async {
    if (_selectedPhotoSizeIndex < 0 ||
        _selectedPhotoSizeIndex >= _photoSizeOptions.length) {
      return;
    }
    final Size selected = _photoSizeOptions[_selectedPhotoSizeIndex];
    final bool shouldApply = _appliedPhotoSize == null ||
        _appliedPhotoSize!.width != selected.width ||
        _appliedPhotoSize!.height != selected.height;
    if (!shouldApply) return;

    await CamerawesomePlugin.setPhotoSize(
      selected.width.round(),
      selected.height.round(),
    );
    _appliedPhotoSize = selected;
  }

  void _cyclePhotoResolution() {
    HapticFeedback.selectionClick();
    if (_isFlashMenuOpen && mounted) {
      setState(() {
        _isFlashMenuOpen = false;
      });
    }
    if (_photoSizeOptions.isEmpty) {
      unawaited(_loadPhotoSizes(resetSelection: true));
      return;
    }
    _selectedPhotoSizeIndex =
        (_selectedPhotoSizeIndex + 1) % _photoSizeOptions.length;
    setState(() {
      _resolutionLabel = _formatMegapixelsLabelFromSize(
        _photoSizeOptions[_selectedPhotoSizeIndex],
      );
    });
    unawaited(_applySelectedPhotoSize());
  }

  void _toggleFlashMenu() {
    HapticFeedback.selectionClick();
    setState(() {
      _isFlashMenuOpen = !_isFlashMenuOpen;
    });
  }

  void _closeFlashMenu() {
    if (!_isFlashMenuOpen || !mounted) return;
    setState(() {
      _isFlashMenuOpen = false;
    });
  }

  Future<void> _setFlashMode(CameraState state, FlashMode mode) async {
    HapticFeedback.selectionClick();
    await state.sensorConfig.setFlashMode(mode);
    if (!mounted) return;
    setState(() {
      _isFlashMenuOpen = false;
    });
  }

  CameraPreviewFit _previewFitForSelectedRatio() {
    if (_selectedAspectRatio == 'Full') {
      return CameraPreviewFit.cover;
    }
    return CameraPreviewFit.contain;
  }

  Alignment _previewAlignmentForSelectedRatio() {
    if (_selectedAspectRatio == '3:4') {
      // Keep 3:4 preview attached to the top so it reaches the icon row.
      return Alignment.topCenter;
    }
    return Alignment.center;
  }

  bool _isBottomPanelTransparent() {
    return _selectedAspectRatio == 'Full' || _selectedAspectRatio == '9:16';
  }

  Widget _buildModeSelectorBar(BuildContext context) {
    final Widget selector = ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ValueListenableBuilder<int>(
        valueListenable: _selectedModeNotifier,
        builder: (context, index, _) {
          return CameraModeSelector(
            modes: _modes,
            selectedIndex: index,
            pageController: _bottomPageController,
            onModeChanged: _onPageChanged,
            onModeTap: _onModeTap,
          );
        },
      ),
    );

    // In 9:16 only keep black from the mode carousel downward.
    if (_selectedAspectRatio == '9:16') {
      return Container(
        color: Colors.black,
        padding: EdgeInsets.only(
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom + 6,
        ),
        child: selector,
      );
    }
    return selector;
  }

  Future<void> _switchCameraFromSwipe(CameraState state) async {
    if (_isCameraSwitchInProgress) return;
    final DateTime now = DateTime.now();
    if (_lastSwipeCameraSwitchAt != null &&
        now.difference(_lastSwipeCameraSwitchAt!) < _cameraSwitchSwipeCooldown) {
      return;
    }

    _isCameraSwitchInProgress = true;
    _lastSwipeCameraSwitchAt = now;
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _cameraSwitchOverlayOpacity = 0.14;
      });
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await _switchCamera(state);
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitchOverlayOpacity = 0.0;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
      _isCameraSwitchInProgress = false;
    }
  }

  void _handleZoomScaleStart(ScaleStartDetails details, CameraState state) {
    if (details.pointerCount < 2) {
      _isSingleFingerSwipeTracking = true;
      _singleFingerSwipeStartY = details.focalPoint.dy;
      _singleFingerSwipeLastY = details.focalPoint.dy;
      return;
    }

    _isSingleFingerSwipeTracking = false;
    _singleFingerSwipeStartY = null;
    _singleFingerSwipeLastY = null;
    _pinchLastScale = 1.0;
    _pinchExpandNotifier.value++;
  }

  void _handleZoomScaleUpdate(ScaleUpdateDetails details, CameraState state) {
    if (details.pointerCount < 2) {
      if (_isSingleFingerSwipeTracking) {
        _singleFingerSwipeLastY = details.focalPoint.dy;
      }
      return;
    }

    _pinchExpandNotifier.value++;
    final double zoomDelta = (details.scale - _pinchLastScale) * 0.8;
    _pinchLastScale = details.scale;
    final double nextZoom = (state.sensorConfig.zoom + zoomDelta).clamp(
      0.0,
      1.0,
    );
    state.sensorConfig.setZoom(nextZoom);
  }

  void _handleZoomScaleEnd(ScaleEndDetails details, CameraState state) {
    if (!_isSingleFingerSwipeTracking) return;

    final double? startY = _singleFingerSwipeStartY;
    final double? endY = _singleFingerSwipeLastY;
    _isSingleFingerSwipeTracking = false;
    _singleFingerSwipeStartY = null;
    _singleFingerSwipeLastY = null;

    if (startY == null || endY == null) return;

    final double dy = endY - startY;
    final double velocityY = details.velocity.pixelsPerSecond.dy;
    final bool distanceOk =
        dy.abs() >= _singleFingerSwipeDistanceThreshold;
    final bool velocityOk =
        velocityY.abs() >= _singleFingerSwipeVelocityThreshold;

    if (!distanceOk && !velocityOk) return;
    if (_isFlashMenuOpen) {
      _closeFlashMenu();
    }
    unawaited(_switchCameraFromSwipe(state));
  }

  @override
  Widget build(BuildContext context) {
    if (!_didApplyBestPhotoSizeOnce) {
      _didApplyBestPhotoSizeOnce = true;
      unawaited(_loadPhotoSizes(resetSelection: true));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraAwesomeBuilder.custom(
            saveConfig: SaveConfig.photoAndVideo(
              photoPathBuilder: (sensors) async {
                final path = await _getPath('.jpg');
                return SingleCaptureRequest(path, sensors.first);
              },
              videoPathBuilder: (sensors) async {
                final path = await _getPath('.mp4');
                return SingleCaptureRequest(path, sensors.first);
              },
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              aspectRatio: CameraAspectRatios.ratio_4_3,
              flashMode: FlashMode.none,
            ),
            previewFit: _previewFitForSelectedRatio(),
            previewAlignment: _previewAlignmentForSelectedRatio(),
            builder: (state, preview) {
              // 👉 Escucha cuando cualquier carrusel se detiene para evitar "frenazos"
              return NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  _applyCameraHardwareMode(state);
                  return false;
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PageView.builder(
                        controller: _modePageController,
                        itemCount: _modes.length,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) =>
                            Container(color: Colors.transparent),
                      ),
                    ),
                    Positioned.fill(
                      bottom: 240,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _closeFlashMenu,
                        onScaleStart: (details) =>
                            _handleZoomScaleStart(details, state),
                        onScaleUpdate: (details) =>
                            _handleZoomScaleUpdate(details, state),
                        onScaleEnd: (details) =>
                            _handleZoomScaleEnd(details, state),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CameraTopBar(
                        aspectRatio: _selectedAspectRatio,
                        resolutionLabel: _resolutionLabel,
                        onResolutionTap: _cyclePhotoResolution,
                        solidBlackBackground: _selectedAspectRatio == '3:4',
                        flashMode: state.sensorConfig.flashMode.name,
                        flashMenuOpen: _isFlashMenuOpen,
                        isRecordingVideo: state is VideoRecordingCameraState,
                        onFlashTap: _toggleFlashMenu,
                        onFlashOffTap: () =>
                            _setFlashMode(state, FlashMode.none),
                        onFlashAutoTap: () =>
                            _setFlashMode(state, FlashMode.auto),
                        onFlashOnTap: () => _setFlashMode(
                          state,
                          state is VideoRecordingCameraState
                              ? FlashMode.always
                              : FlashMode.on,
                        ),
                        onAspectRatioTap: () => _toggleAspectRatio(state),
                        onSettingsTap: () {},
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        bottom: _selectedAspectRatio != '9:16',
                        child: Container(
                          height: 252,
                          color: _isBottomPanelTransparent()
                              ? Colors.transparent
                              : Colors.black,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ZoomSelector(
                                sensorConfig: state.sensorConfig,
                                pinchExpandNotifier: _pinchExpandNotifier,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _CircularPreview(onTap: () {}),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _selectedModeNotifier,
                                      builder: (context, index, _) {
                                        return ShutterButton(
                                          isVideoMode: index == 2,
                                          isRecording: state
                                              is VideoRecordingCameraState,
                                          onTap: () {
                                            state.when(
                                              onPhotoMode: (s) => s.takePhoto(),
                                              onVideoMode: (s) =>
                                                  s.startRecording(),
                                              onVideoRecordingMode: (s) =>
                                                  s.stopRecording(),
                                              onPreviewMode: (s) {},
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    _CircularIconButton(
                                      icon: Icons.cached_rounded,
                                      onTap: () => _switchCamera(state),
                                    ),
                                  ],
                                ),
                              ),
                              _buildModeSelectorBar(context),
                              SizedBox(
                                height: _selectedAspectRatio == '9:16'
                                    ? 0
                                    : 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _cameraSwitchOverlayOpacity,
                child: Container(color: Colors.black),
              ),
            ),
          ),
          if (_isAppInBackground)
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Icon(
                  CupertinoIcons.lock_shield,
                  color: Colors.white24,
                  size: 50,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// (Tus selectores _ZoomSelector, _CircularPreview, etc. se mantienen idénticos)
class _ZoomSelector extends StatefulWidget {
  final SensorConfig sensorConfig;
  final ValueNotifier<int> pinchExpandNotifier;
  const _ZoomSelector({
    required this.sensorConfig,
    required this.pinchExpandNotifier,
  });
  @override
  State<_ZoomSelector> createState() => _ZoomSelectorState();
}

class _ZoomSelectorState extends State<_ZoomSelector> {
  bool _isExpanded = false;
  Timer? _collapseTimer;
  StreamSubscription<double>? _zoomSubscription;
  double _currentZoom = 0.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _isBoundsReady = false;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.sensorConfig.zoom;
    _zoomSubscription = widget.sensorConfig.zoom$.listen(_onZoomChanged);
    widget.pinchExpandNotifier.addListener(_onPinchExpandRequested);
    _loadZoomBounds();
  }

  @override
  void didUpdateWidget(covariant _ZoomSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorConfig != widget.sensorConfig) {
      _zoomSubscription?.cancel();
      _currentZoom = widget.sensorConfig.zoom;
      _zoomSubscription = widget.sensorConfig.zoom$.listen(_onZoomChanged);
      _loadZoomBounds();
    }
    if (oldWidget.pinchExpandNotifier != widget.pinchExpandNotifier) {
      oldWidget.pinchExpandNotifier.removeListener(_onPinchExpandRequested);
      widget.pinchExpandNotifier.addListener(_onPinchExpandRequested);
    }
  }

  @override
  void dispose() {
    widget.pinchExpandNotifier.removeListener(_onPinchExpandRequested);
    _zoomSubscription?.cancel();
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _onZoomChanged(double zoom) {
    if (!mounted) return;
    setState(() {
      _currentZoom = zoom;
    });
  }

  void _onPinchExpandRequested() {
    if (!mounted) return;
    setState(() {
      _expandAndResetTimer();
    });
  }

  Future<void> _loadZoomBounds() async {
    try {
      final double minZoom = await CamerawesomePlugin.getMinZoom() ?? 1.0;
      final double maxZoom = await CamerawesomePlugin.getMaxZoom() ?? 1.0;
      if (!mounted) return;
      setState(() {
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _isBoundsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _isBoundsReady = true;
      });
    }
  }

  void _expandAndResetTimer() {
    _isExpanded = true;
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );
  }

  String _zoomLabel(double value) {
    final double displayZoom = _toDisplayZoom(value);
    return '${displayZoom.toStringAsFixed(displayZoom >= 10 ? 0 : 1)}x';
  }

  double _toDisplayZoom(double normalizedZoom) {
    if (!_isBoundsReady) {
      return normalizedZoom;
    }
    return (_maxZoom - _minZoom) * normalizedZoom + _minZoom;
  }

  double _toNormalizedZoom(double displayZoom) {
    if (!_isBoundsReady || (_maxZoom - _minZoom).abs() < 0.0001) {
      return 0.0;
    }
    return ((displayZoom - _minZoom) / (_maxZoom - _minZoom)).clamp(0.0, 1.0);
  }

  List<double> _displayStops({required bool expanded}) {
    if (!_isBoundsReady) {
      return [1.0];
    }
    final List<double> candidates = expanded
        ? [_minZoom, 1.0, 2.0, 3.0, 5.0, 10.0, _maxZoom]
        : [_minZoom, 1.0, 2.0, _maxZoom];
    final List<double> filtered = <double>[];

    for (final double value in candidates) {
      if (value < _minZoom || value > _maxZoom) continue;
      final bool alreadyAdded = filtered.any((e) => (e - value).abs() < 0.05);
      if (!alreadyAdded) {
        filtered.add(value);
      }
    }

    if (filtered.isEmpty) {
      return [_minZoom];
    }
    return filtered;
  }

  String _stopLabel(double displayZoom) {
    return displayZoom >= 10
        ? displayZoom.toStringAsFixed(0)
        : displayZoom.toStringAsFixed(1).replaceAll('.0', '');
  }

  bool _isStopSelected(double displayZoom) {
    final double currentDisplayZoom = _toDisplayZoom(_currentZoom);
    return (currentDisplayZoom - displayZoom).abs() <= 0.15;
  }

  Widget _buildCollapsedView() {
    return Align(
      key: const ValueKey('collapsed'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(150),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _displayStops(expanded: false)
              .map(
                (displayZoom) => _zoomBtn(
                  _stopLabel(displayZoom),
                  _toNormalizedZoom(displayZoom),
                  isSelected: _isStopSelected(displayZoom),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return SizedBox(
      key: const ValueKey('expanded'),
      height: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _zoomLabel(_currentZoom),
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 26,
            width: double.infinity,
            child: ClipRect(
              child: CustomPaint(
                painter: _RulerPainter(zoom: _currentZoom),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._displayStops(expanded: true).map(
                      (displayZoom) => _expandedZoomBtn(
                        _stopLabel(displayZoom),
                        _toNormalizedZoom(displayZoom),
                        isSelected: _isStopSelected(displayZoom),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomBtn(String label, double value, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.sensorConfig.setZoom(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedZoomBtn(
    String label,
    double value, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.sensorConfig.setZoom(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double zoom;
  _RulerPainter({required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final double startX = 10;
    final double endX = size.width - 10;
    final double centerY = size.height / 2;
    final double clampedZoom = zoom.clamp(0.0, 1.0);

    final Paint baseLinePaint = Paint()
      ..color = Colors.white.withAlpha(65)
      ..strokeWidth = 1.2;

    final Paint tickPaint = Paint()
      ..color = Colors.white.withAlpha(150)
      ..strokeWidth = 1.0;

    // Regla finita: parte en min zoom de hardware y termina en max zoom.
    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), baseLinePaint);

    const int tickCount = 28;
    for (int i = 0; i <= tickCount; i++) {
      final double t = i / tickCount;
      final double x = startX + (endX - startX) * t;
      final bool isMajor = i % 4 == 0;
      final double tickHeight = isMajor ? 14 : 8;
      canvas.drawLine(
        Offset(x, centerY - tickHeight / 2),
        Offset(x, centerY + tickHeight / 2),
        tickPaint,
      );
    }

    final double indicatorX = startX + (endX - startX) * clampedZoom;
    final Paint activePaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(indicatorX, centerY - 12.5),
      Offset(indicatorX, centerY + 12.5),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) => oldDelegate.zoom != zoom;
}

class _CircularPreview extends StatelessWidget {
  final VoidCallback onTap;
  const _CircularPreview({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: const ClipOval(
          child: Icon(CupertinoIcons.photo, color: Colors.white54),
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircularIconButton({required this.icon, required this.onTap});

  @override
  State<_CircularIconButton> createState() => _CircularIconButtonState();
}

class _CircularIconButtonState extends State<_CircularIconButton>
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
          turns: Tween(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
