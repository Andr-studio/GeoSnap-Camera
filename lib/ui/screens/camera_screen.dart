import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:geosnap_cam/services/gps_service.dart';
import 'package:geosnap_cam/services/watermark_service.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings_screen.dart';
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
  static const int _imageModeIndex = 0;
  static const int _videoModeIndex = 1;

  final List<String> _modes = ['Imagen', 'Video'];
  late PageController _modePageController;
  late PageController _bottomPageController;
  final ValueNotifier<int> _selectedModeNotifier = ValueNotifier(
    _imageModeIndex,
  );
  final ValueNotifier<int> _pinchExpandNotifier = ValueNotifier(0);
  int _pendingCameraMode = _imageModeIndex;
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
  bool _isCaptureActionInProgress = false;
  bool _isModeChangeInProgress = false;
  DateTime? _lastShutterTapAt;
  Timer? _recordingTimer;
  Timer? _focusUiTimer;
  Timer? _focusLockTimer;
  Duration _recordingElapsed = Duration.zero;
  bool _galleryAccessChecked = false;
  bool _galleryAccessGranted = false;
  String? _lastCapturePath;
  bool _lastCaptureIsVideo = false;
  bool _gpsReadyHapticPlayed = false;
  Offset? _focusPoint;
  bool _focusLocked = false;
  bool _focusIndicatorVisible = false;
  bool _exposureControlVisible = false;
  double _brightness = 0.5;
  double _iconRotationTurns = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static const double _defaultMegapixels = 12.0;
  static const double _highResMegapixelsThreshold = 40.0;
  static const Duration _shutterDebounce = Duration(milliseconds: 220);
  static const double _singleFingerSwipeDistanceThreshold = 70.0;
  static const double _singleFingerSwipeVelocityThreshold = 700.0;
  static const Duration _cameraSwitchSwipeCooldown = Duration(
    milliseconds: 700,
  );
  static const Duration _focusLockPressDuration = Duration(seconds: 1);
  static const String _galleryAlbumName = 'GeoSnap';
  List<Size> _photoSizeOptions = <Size>[];
  int _selectedPhotoSizeIndex = -1;
  Size? _appliedPhotoSize;

  final GpsService _gpsService = GpsService();
  LocationData? _lastKnownLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request permission and start location track
    _initLocation();

    _modePageController = PageController(
      initialPage: _selectedModeNotifier.value,
    );
    _bottomPageController = PageController(
      initialPage: _selectedModeNotifier.value,
      viewportFraction: 0.22,
    );

    _lastHapticPosition = _selectedModeNotifier.value.toDouble();
    _startIconOrientationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _focusUiTimer?.cancel();
    _focusLockTimer?.cancel();
    _accelerometerSubscription?.cancel();
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
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  Future<void> _initLocation() async {
    final loc = await _gpsService.getCurrentLocation();
    if (loc != null) {
      _lastKnownLocation = loc;
      final WatermarkConfig config = await WatermarkService.getConfig();
      await WatermarkService.prewarmWatermarkAssets(loc, config);
      if (!_gpsReadyHapticPlayed) {
        _gpsReadyHapticPlayed = true;
        HapticFeedback.mediumImpact();
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startIconOrientationTracking() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((event) {
          final double x = event.x;
          final double y = event.y;
          if (x.abs() < 5.8 && y.abs() < 5.8) return;

          final double nextTurns;
          if (x.abs() > y.abs()) {
            nextTurns = x > 0 ? 0.25 : -0.25;
          } else {
            nextTurns = y > 0 ? 0.0 : 0.5;
          }

          if (!mounted || (_iconRotationTurns - nextTurns).abs() < 0.01) return;
          setState(() {
            _iconRotationTurns = nextTurns;
          });
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
    if (state is VideoRecordingCameraState) return;
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

    HapticFeedback.mediumImpact();
    _selectedModeNotifier.value = index;
  }

  void _onModeTap(int index, CameraState state) {
    if (state is VideoRecordingCameraState) return;
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
    if (_selectedModeNotifier.value != index) {
      HapticFeedback.mediumImpact();
      _selectedModeNotifier.value = index;
    }
    unawaited(_applyCameraHardwareMode(state));
  }

  // 👉 Actualiza el Hardware SOLO cuando el deslizamiento termina
  Future<void> _applyCameraHardwareMode(CameraState state) async {
    if (_isModeChangeInProgress) return;
    final int selectedIndex = _selectedModeNotifier.value;
    if (_pendingCameraMode == selectedIndex) return;
    _isModeChangeInProgress = true;

    try {
      if (state is VideoRecordingCameraState &&
          selectedIndex != _videoModeIndex) {
        await state.stopRecording();
        _stopRecordingTimer();
      }

      if (selectedIndex == _imageModeIndex) {
        state.setState(CaptureMode.photo);
      } else if (selectedIndex == _videoModeIndex) {
        state.setState(CaptureMode.video);
      }
      _pendingCameraMode = selectedIndex;
    } finally {
      _isModeChangeInProgress = false;
    }
  }

  Future<void> _handleShutterTap(CameraState state) async {
    if (_isCaptureActionInProgress) return;
    final DateTime now = DateTime.now();
    if (_lastShutterTapAt != null &&
        now.difference(_lastShutterTapAt!) < _shutterDebounce) {
      return;
    }
    _lastShutterTapAt = now;
    _isCaptureActionInProgress = true;

    try {
      await _applyCameraHardwareMode(state);
      final bool wantsVideo = _selectedModeNotifier.value == _videoModeIndex;

      if (wantsVideo) {
        if (state is VideoRecordingCameraState) {
          await state.stopRecording();
          _stopRecordingTimer();
        } else if (state is VideoCameraState) {
          await state.startRecording();
          _startRecordingTimer();
        } else {
          state.setState(CaptureMode.video);
        }
      } else {
        if (state is PhotoCameraState) {
          await state.takePhoto();
        } else if (state is VideoRecordingCameraState) {
          await state.stopRecording();
          _stopRecordingTimer();
          state.setState(CaptureMode.photo);
        } else {
          state.setState(CaptureMode.photo);
        }
      }
    } finally {
      _isCaptureActionInProgress = false;
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    if (mounted) {
      setState(() {
        _recordingElapsed = Duration.zero;
      });
    } else {
      _recordingElapsed = Duration.zero;
    }
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _recordingElapsed += const Duration(seconds: 1);
      });
    });
  }

  void _stopRecordingTimer({bool reset = true}) {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (reset && mounted) {
      setState(() {
        _recordingElapsed = Duration.zero;
      });
    } else if (reset) {
      _recordingElapsed = Duration.zero;
    }
  }

  String _recordingTimeLabel() {
    final int totalSeconds = _recordingElapsed.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _ensureGalleryAccess() async {
    if (_galleryAccessChecked) return _galleryAccessGranted;
    _galleryAccessChecked = true;
    try {
      final bool hasAccess = await Gal.hasAccess();
      if (hasAccess) {
        _galleryAccessGranted = true;
        return true;
      }
      _galleryAccessGranted = await Gal.requestAccess();
      return _galleryAccessGranted;
    } catch (_) {
      _galleryAccessGranted = false;
      return false;
    }
  }

  Future<void> _saveMediaToGallery(MediaCapture mediaCapture) async {
    if (mediaCapture.status != MediaCaptureStatus.success) return;
    String? path = mediaCapture.captureRequest.path;
    if (path == null || path.isEmpty) return;
    if (!await File(path).exists()) return;
    if (!await _ensureGalleryAccess()) return;

    // Use last known location directly to eliminate GPS fetch delay
    LocationData? loc = _lastKnownLocation;

    if (loc != null) {
      path = await WatermarkService.applyWatermark(
        path,
        mediaCapture.isVideo,
        loc,
      );
      if (mounted) {
        setState(() {
          _lastCapturePath = path;
        });
      }
    }

    try {
      if (mediaCapture.isPicture) {
        await Gal.putImage(path, album: _galleryAlbumName);
      } else if (mediaCapture.isVideo) {
        await Gal.putVideo(path, album: _galleryAlbumName);
      }
    } catch (_) {
      // Keep capture flow resilient if gallery save fails on specific devices.
    }
  }

  void _onMediaCaptureEvent(MediaCapture mediaCapture) {
    if (mediaCapture.isVideo) {
      if (mediaCapture.status == MediaCaptureStatus.capturing &&
          mediaCapture.videoState == VideoState.started) {
        if (_recordingTimer == null) {
          _startRecordingTimer();
        }
      } else if (mediaCapture.status != MediaCaptureStatus.capturing ||
          mediaCapture.videoState == VideoState.stopped ||
          mediaCapture.videoState == VideoState.error) {
        _stopRecordingTimer();
      }
    }

    if (mediaCapture.status == MediaCaptureStatus.success) {
      final String? path = mediaCapture.captureRequest.path;
      if (mounted && path != null && path.isNotEmpty) {
        setState(() {
          _lastCapturePath = path;
          _lastCaptureIsVideo = mediaCapture.isVideo;
        });
      }
      unawaited(_saveMediaToGallery(mediaCapture));
    }
  }

  Future<void> _openLastCapturePreview() async {
    final String? path = _lastCapturePath;
    if (path == null || path.isEmpty) return;
    if (!await File(path).exists()) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _MediaPreviewScreen(mediaPath: path, isVideo: _lastCaptureIsVideo),
      ),
    );
  }

  Future<void> _toggleAspectRatio(CameraState state) async {
    if (state is VideoRecordingCameraState) return;
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

    final bool sameSize =
        baseSize.width == highResSize.width &&
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
    final bool shouldApply =
        _appliedPhotoSize == null ||
        _appliedPhotoSize!.width != selected.width ||
        _appliedPhotoSize!.height != selected.height;
    if (!shouldApply) return;

    await CamerawesomePlugin.setPhotoSize(
      selected.width.round(),
      selected.height.round(),
    );
    _appliedPhotoSize = selected;
  }

  void _cyclePhotoResolution(CameraState state) {
    if (state is VideoRecordingCameraState) return;
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

  Widget _buildModeSelectorBar(BuildContext context, CameraState state) {
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
            onModeTap: (modeIndex) => _onModeTap(modeIndex, state),
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
    if (state is VideoRecordingCameraState) return;
    if (_isCameraSwitchInProgress) return;
    final DateTime now = DateTime.now();
    if (_lastSwipeCameraSwitchAt != null &&
        now.difference(_lastSwipeCameraSwitchAt!) <
            _cameraSwitchSwipeCooldown) {
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

    _cancelFocusLockTimer();
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
        final double? startY = _singleFingerSwipeStartY;
        if (startY != null && (details.focalPoint.dy - startY).abs() > 10) {
          _cancelFocusLockTimer();
        }
      }
      return;
    }

    _cancelFocusLockTimer();
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
    final bool distanceOk = dy.abs() >= _singleFingerSwipeDistanceThreshold;
    final bool velocityOk =
        velocityY.abs() >= _singleFingerSwipeVelocityThreshold;

    if (!distanceOk && !velocityOk) return;
    if (_isFlashMenuOpen) {
      _closeFlashMenu();
    }
    unawaited(_switchCameraFromSwipe(state));
  }

  Future<void> _focusPreviewAt(
    CameraState state,
    Offset localPosition,
    Size previewSize, {
    required bool lock,
    required bool showExposureControl,
  }) async {
    if (previewSize.width <= 0 || previewSize.height <= 0) return;

    HapticFeedback.selectionClick();
    _focusUiTimer?.cancel();
    if (mounted) {
      setState(() {
        _focusPoint = localPosition;
        _focusLocked = lock;
        _focusIndicatorVisible = true;
        _exposureControlVisible = showExposureControl;
      });
    }

    try {
      final PreviewSize pixelPreviewSize = await state.previewSize(0);
      final PreviewSize flutterPreviewSize = PreviewSize(
        width: previewSize.width,
        height: previewSize.height,
      );
      final AndroidFocusSettings androidFocusSettings = AndroidFocusSettings(
        autoCancelDurationInMillis: lock ? 0 : 5000,
      );

      await state.when(
        onPhotoMode: (photoState) => photoState.focusOnPoint(
          flutterPosition: localPosition,
          pixelPreviewSize: pixelPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
          androidFocusSettings: androidFocusSettings,
        ),
        onVideoMode: (videoState) => videoState.focusOnPoint(
          flutterPosition: localPosition,
          pixelPreviewSize: pixelPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
          androidFocusSettings: androidFocusSettings,
        ),
        onVideoRecordingMode: (videoRecState) => videoRecState.focusOnPoint(
          flutterPosition: localPosition,
          pixelPreviewSize: pixelPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
          androidFocusSettings: androidFocusSettings,
        ),
        onPreviewMode: (previewState) => previewState.focusOnPoint(
          flutterPosition: localPosition,
          pixelPreviewSize: pixelPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
          androidFocusSettings: androidFocusSettings,
        ),
      );
    } catch (_) {
      // Some devices may reject focus points while the camera is reconfiguring.
    }

    if (!lock) {
      _focusUiTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || _focusLocked) return;
        setState(() {
          _focusIndicatorVisible = false;
          _exposureControlVisible = false;
        });
      });
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _setBrightness(CameraState state, double value) {
    final double next = value.clamp(0.0, 1.0).toDouble();
    setState(() {
      _brightness = next;
      _focusIndicatorVisible = true;
      _exposureControlVisible = true;
    });
    state.sensorConfig.setBrightness(next);
  }

  void _cancelFocusLockTimer() {
    _focusLockTimer?.cancel();
    _focusLockTimer = null;
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
              videoOptions: VideoOptions(
                enableAudio: true,
                quality: VideoRecordingQuality.highest,
                android: AndroidVideoOptions(
                  fallbackStrategy: QualityFallbackStrategy.lower,
                ),
                ios: CupertinoVideoOptions(
                  codec: CupertinoCodecType.h264,
                  fileType: CupertinoFileType.mpeg4,
                ),
              ),
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
            onMediaCaptureEvent: _onMediaCaptureEvent,
            builder: (state, preview) {
              // 👉 Escucha cuando cualquier carrusel se detiene para evitar "frenazos"
              return NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  unawaited(_applyCameraHardwareMode(state));
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final Size previewTouchSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (details) {
                              _closeFlashMenu();
                              _cancelFocusLockTimer();
                              unawaited(
                                _focusPreviewAt(
                                  state,
                                  details.localPosition,
                                  previewTouchSize,
                                  lock: false,
                                  showExposureControl: false,
                                ),
                              );
                              _focusLockTimer = Timer(
                                _focusLockPressDuration,
                                () {
                                  unawaited(
                                    _focusPreviewAt(
                                      state,
                                      details.localPosition,
                                      previewTouchSize,
                                      lock: true,
                                      showExposureControl: true,
                                    ),
                                  );
                                },
                              );
                            },
                            onTapUp: (_) => _cancelFocusLockTimer(),
                            onTapCancel: _cancelFocusLockTimer,
                            onScaleStart: (details) =>
                                _handleZoomScaleStart(details, state),
                            onScaleUpdate: (details) =>
                                _handleZoomScaleUpdate(details, state),
                            onScaleEnd: (details) =>
                                _handleZoomScaleEnd(details, state),
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    ),

                    Positioned.fill(
                      bottom: 240,
                      child: _FocusExposureOverlay(
                        point: _focusPoint,
                        locked: _focusLocked,
                        visible: _focusIndicatorVisible,
                        exposureVisible: _exposureControlVisible,
                        brightness: _brightness,
                        onBrightnessChanged: (value) =>
                            _setBrightness(state, value),
                      ),
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CameraTopBar(
                        aspectRatio: _selectedAspectRatio,
                        resolutionLabel: _resolutionLabel,
                        onResolutionTap: () => _cyclePhotoResolution(state),
                        solidBlackBackground: _selectedAspectRatio == '3:4',
                        flashMode: state.sensorConfig.flashMode.name,
                        flashMenuOpen: _isFlashMenuOpen,
                        isRecordingVideo: state is VideoRecordingCameraState,
                        gpsReady: _lastKnownLocation != null,
                        recordingTimeLabel: state is VideoRecordingCameraState
                            ? _recordingTimeLabel()
                            : null,
                        iconRotationTurns: _iconRotationTurns,
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
                        onSettingsTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WatermarkSettingsScreen(
                                currentLocation: _lastKnownLocation,
                              ),
                            ),
                          );
                          if (_lastKnownLocation != null) {
                            final WatermarkConfig config =
                                await WatermarkService.getConfig();
                            await WatermarkService.prewarmWatermarkAssets(
                              _lastKnownLocation,
                              config,
                            );
                          }
                          if (mounted) {
                            setState(() {});
                          }
                        },
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
                                compactMode: _selectedAspectRatio == '9:16',
                                iconRotationTurns: _iconRotationTurns,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _CircularPreview(
                                      onTap: _openLastCapturePreview,
                                      filePath: _lastCapturePath,
                                      isVideo: _lastCaptureIsVideo,
                                      iconRotationTurns: _iconRotationTurns,
                                    ),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _selectedModeNotifier,
                                      builder: (context, index, _) {
                                        return ShutterButton(
                                          key: ValueKey<String>(
                                            'shutter-$index-${state.runtimeType}',
                                          ),
                                          isVideoMode: index == _videoModeIndex,
                                          isRecording:
                                              state
                                                  is VideoRecordingCameraState,
                                          onTap: () => _handleShutterTap(state),
                                        );
                                      },
                                    ),
                                    _CircularIconButton(
                                      icon: Icons.cached_rounded,
                                      rotationTurns: _iconRotationTurns,
                                      onTap: () => _switchCamera(state),
                                    ),
                                  ],
                                ),
                              ),
                              _buildModeSelectorBar(context, state),
                              SizedBox(
                                height: _selectedAspectRatio == '9:16' ? 0 : 5,
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
  final bool compactMode;
  final double iconRotationTurns;

  const _ZoomSelector({
    required this.sensorConfig,
    required this.pinchExpandNotifier,
    this.compactMode = false,
    this.iconRotationTurns = 0.0,
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
    // Keep 9:16 stable: avoid carrying expanded state that can overflow.
    if (widget.compactMode && _isExpanded) {
      _collapseTimer?.cancel();
      _isExpanded = false;
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
    if (widget.compactMode) {
      // In 9:16 we keep the compact zoom bar while pinching to prevent overflow.
      return;
    }
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
      child: ClipRect(
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
    final bool compact = widget.compactMode;
    return SizedBox(
      key: const ValueKey('expanded'),
      height: compact ? 82 : 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedRotation(
              turns: widget.iconRotationTurns,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Text(
                _zoomLabel(_currentZoom),
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          SizedBox(
            height: compact ? 20 : 26,
            width: double.infinity,
            child: ClipRect(
              child: CustomPaint(painter: _RulerPainter(zoom: _currentZoom)),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            height: compact ? 24 : 28,
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
                        compact: compact,
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
          child: AnimatedRotation(
            turns: widget.iconRotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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
      ),
    );
  }

  Widget _expandedZoomBtn(
    String label,
    double value, {
    bool compact = false,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.sensorConfig.setZoom(value);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 15),
        child: AnimatedRotation(
          turns: widget.iconRotationTurns,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFD700) : Colors.white,
              fontSize: compact ? 14 : 16,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
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
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      baseLinePaint,
    );

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
  final String? filePath;
  final bool isVideo;
  final double iconRotationTurns;
  const _CircularPreview({
    required this.onTap,
    this.filePath,
    this.isVideo = false,
    this.iconRotationTurns = 0.0,
  });
  @override
  Widget build(BuildContext context) {
    final bool hasMedia =
        filePath != null &&
        filePath!.isNotEmpty &&
        File(filePath!).existsSync();

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
        child: ClipOval(
          child: AnimatedRotation(
            turns: iconRotationTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: hasMedia
                ? Stack(
                    fit: StackFit.expand,
                    children: [
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

class _MediaPreviewScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;
  const _MediaPreviewScreen({required this.mediaPath, required this.isVideo});

  @override
  State<_MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _FocusExposureOverlay extends StatelessWidget {
  final Offset? point;
  final bool locked;
  final bool visible;
  final bool exposureVisible;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  const _FocusExposureOverlay({
    required this.point,
    required this.locked,
    required this.visible,
    required this.exposureVisible,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Offset? focusPoint = point;
    if (focusPoint == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double x = focusPoint.dx.clamp(54.0, constraints.maxWidth - 96.0);
        final double y = focusPoint.dy.clamp(
          54.0,
          constraints.maxHeight - 96.0,
        );
        final bool sliderOnRight = x < constraints.maxWidth - 122;
        final double sliderLeft = sliderOnRight ? x + 42 : x - 104;
        final double sliderTop = (y - 84).clamp(
          12.0,
          constraints.maxHeight - 188.0,
        );

        return IgnorePointer(
          ignoring: !exposureVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: x - 31,
                  top: y - 31,
                  child: _FocusRing(locked: locked),
                ),
                Positioned(
                  left: sliderLeft,
                  top: sliderTop,
                  child: IgnorePointer(
                    ignoring: !exposureVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: exposureVisible ? 1 : 0,
                      child: _ExposureSlider(
                        value: brightness,
                        locked: locked,
                        onChanged: onBrightnessChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FocusRing extends StatelessWidget {
  final bool locked;

  const _FocusRing({required this.locked});

  @override
  Widget build(BuildContext context) {
    final Color color = locked ? const Color(0xFFFFD54F) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.8),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 18),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: locked
              ? const Icon(
                  CupertinoIcons.lock_fill,
                  key: ValueKey<String>('locked'),
                  color: Color(0xFFFFD54F),
                  size: 18,
                )
              : Container(
                  key: const ValueKey<String>('unlocked'),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExposureSlider extends StatelessWidget {
  final double value;
  final bool locked;
  final ValueChanged<double> onChanged;

  const _ExposureSlider({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = locked ? const Color(0xFFFFD54F) : Colors.white;

    return Container(
      width: 48,
      height: 176,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Icon(CupertinoIcons.sun_max_fill, color: accent, size: 18),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.14),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPreviewScreenState extends State<_MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;

  Future<bool> _tryLaunchAndroidIntent(AndroidIntent intent) async {
    try {
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openSystemGallery() async {
    try {
      if (Platform.isAndroid) {
        final List<AndroidIntent> intents = [
          // 1. Native Samsung Gallery (Main)
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.sec.android.gallery3d',
            flags: [268435456],
          ),
          // 2. Generic Gallery Category
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.APP_GALLERY',
            flags: [268435456],
          ),
          // 3. Google Photos (Fallback)
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.photos',
            flags: [268435456],
          ),
          // 4. Standard View for Images
          const AndroidIntent(
            action: 'android.intent.action.VIEW',
            type: 'image/*',
            flags: [268435456],
          ),
          // 5. Modern Photo Picker
          const AndroidIntent(action: 'android.provider.action.PICK_IMAGES'),
        ];

        for (final intent in intents) {
          final bool launched = await _tryLaunchAndroidIntent(intent);
          if (launched) return;
        }
        throw Exception('No gallery intent resolved');
      }
      await Gal.open();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la galeria del sistema'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final controller = VideoPlayerController.file(File(widget.mediaPath));
      _videoController = controller;
      _videoInitFuture = controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        setState(() {});
        controller.play();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Abrir galeria',
            icon: const Icon(CupertinoIcons.photo_on_rectangle),
            onPressed: _openSystemGallery,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: widget.isVideo ? _buildVideoView() : _buildImageView(),
      ),
    );
  }

  Widget _buildImageView() {
    return Center(
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Image.file(
          File(widget.mediaPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'No se pudo cargar la imagen',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final controller = _videoController;
    final double controlsBottomInset =
        MediaQuery.of(context).padding.bottom + 20;
    if (controller == null) {
      return const Center(
        child: Text(
          'No se pudo cargar el video',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _videoInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator(radius: 12));
        }
        if (snapshot.hasError || !controller.value.isInitialized) {
          return const Center(
            child: Text(
              'No se pudo cargar el video',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: controlsBottomInset),
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

class _CircularIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double rotationTurns;

  const _CircularIconButton({
    required this.icon,
    required this.onTap,
    this.rotationTurns = 0.0,
  });

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
