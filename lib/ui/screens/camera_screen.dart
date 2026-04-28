import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:geosnap_cam/core/di/service_locator.dart';
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
  bool _isWatermarkProcessing = false;
  final List<String> _sessionPaths = [];
  final List<bool> _sessionIsVideo = [];
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

  final GpsService _gpsService = appLocator<GpsService>();
  final WatermarkService _watermarkService = appLocator<WatermarkService>();
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
    // Load the GeoSnap folder so previous session files populate the strip.
    unawaited(_loadRecentSession());
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
      final WatermarkConfig config = await _watermarkService.getConfig();
      await _watermarkService.prewarmWatermarkAssets(loc, config);
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

  // ── Permanent storage ─────────────────────────────────────────────────────

  /// Returns (and creates if needed) the permanent GeoSnap output directory
  /// inside getApplicationDocumentsDirectory(). Files here survive app restarts
  /// and are NOT deleted by the OS temp-file cleaner.
  Future<Directory> _getGeoSnapDir() async {
    final Directory base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'GeoSnap')).create(recursive: true);
  }

  /// Builds a unique output path inside the permanent GeoSnap directory.
  Future<String> _getPermanentOutputPath(String extension) async {
    final Directory dir = await _getGeoSnapDir();
    final String ts = DateTime.now().millisecondsSinceEpoch.toString();
    return p.join(dir.path, 'geosnap_$ts$extension');
  }

  /// Scans the GeoSnap directory and loads the most recent files into the
  /// session so the thumbnail and strip are populated on every app launch.
  Future<void> _loadRecentSession() async {
    try {
      final Directory dir = await _getGeoSnapDir();
      if (!dir.existsSync()) return;

      const Set<String> photoExts = {'.jpg', '.jpeg', '.png', '.heic'};
      const Set<String> videoExts = {'.mp4', '.mov', '.mkv'};
      const int maxSessionFiles = 30;

      final List<FileSystemEntity> entities = dir.listSync(followLinks: false)
        ..sort((a, b) {
          // Sort by last modified, newest first.
          final int aMs = (a is File
              ? a.lastModifiedSync().millisecondsSinceEpoch
              : 0);
          final int bMs = (b is File
              ? b.lastModifiedSync().millisecondsSinceEpoch
              : 0);
          return bMs.compareTo(aMs);
        });

      final List<String> paths = [];
      final List<bool> isVideos = [];

      for (final FileSystemEntity entity in entities) {
        if (entity is! File) continue;
        final String ext = p.extension(entity.path).toLowerCase();
        if (!photoExts.contains(ext) && !videoExts.contains(ext)) continue;
        paths.add(entity.path);
        isVideos.add(videoExts.contains(ext));
        if (paths.length >= maxSessionFiles) break;
      }

      // Reverse so the strip shows oldest → newest (newest at the right).
      final List<String> orderedPaths = paths.reversed.toList();
      final List<bool> orderedIsVideo = isVideos.reversed.toList();

      if (!mounted) return;
      setState(() {
        _sessionPaths
          ..clear()
          ..addAll(orderedPaths);
        _sessionIsVideo
          ..clear()
          ..addAll(orderedIsVideo);
        if (orderedPaths.isNotEmpty) {
          _lastCapturePath = orderedPaths.last;
          _lastCaptureIsVideo = orderedIsVideo.last;
        }
      });
    } catch (_) {
      // Do not crash camera if session loading fails.
    }
  }

  // ── Raw capture path (temp) ────────────────────────────────────────────────

  /// Camerawesome writes the raw capture here. Temporary — it will be processed
  /// and the watermarked copy written to the permanent GeoSnap directory.
  Future<String> _getPath(String extension) async {
    final Directory extDir = await getTemporaryDirectory();
    final Directory tempDir = await Directory(
      p.join(extDir.path, 'GeoSnap_raw'),
    ).create(recursive: true);
    return p.join(
      tempDir.path,
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
    final String? rawPath = mediaCapture.captureRequest.path;
    if (rawPath == null || rawPath.isEmpty) return;
    if (!await File(rawPath).exists()) return;
    if (!await _ensureGalleryAccess()) return;

    // Show spinner on the thumbnail while the watermark is being applied.
    if (mounted) setState(() => _isWatermarkProcessing = true);

    // Build the permanent output path BEFORE calling applyWatermark so the
    // watermarked file lands directly in the GeoSnap folder.
    final String extension = p.extension(rawPath);
    final String permanentPath = await _getPermanentOutputPath(extension);

    // Use last known location directly to eliminate GPS fetch delay.
    final LocationData? loc = _lastKnownLocation;

    // finalPath: watermarked permanent file, or original raw if no GPS.
    String finalPath = rawPath;

    if (loc != null) {
      finalPath = await _watermarkService.applyWatermark(
        rawPath,
        mediaCapture.isVideo,
        loc,
        outputPath: permanentPath,
      );
    } else {
      // No GPS — copy the raw file to the permanent directory as-is.
      try {
        await File(rawPath).copy(permanentPath);
        finalPath = permanentPath;
      } catch (_) {
        finalPath = rawPath;
      }
    }

    // Register the FINAL path in the session so the viewer always shows the
    // same watermarked file that ends up in the gallery.
    if (mounted) {
      setState(() {
        _lastCapturePath = finalPath;
        _isWatermarkProcessing = false;
        if (!_sessionPaths.contains(finalPath)) {
          _sessionPaths.add(finalPath);
          _sessionIsVideo.add(mediaCapture.isVideo);
        }
      });
    }

    // Save to the system gallery so it appears in Samsung Gallery / Google Photos.
    try {
      if (mediaCapture.isPicture) {
        await Gal.putImage(finalPath, album: _galleryAlbumName);
      } else if (mediaCapture.isVideo) {
        await Gal.putVideo(finalPath, album: _galleryAlbumName);
      }
    } catch (_) {
      // Keep capture flow resilient if gallery save fails on specific devices.
      if (mounted) setState(() => _isWatermarkProcessing = false);
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
      // Update the isVideo flag immediately so the thumbnail icon is correct
      // while the watermark is being processed in the background.
      if (mounted) {
        setState(() {
          _lastCaptureIsVideo = mediaCapture.isVideo;
        });
      }
      // _saveMediaToGallery applies the watermark and THEN registers the
      // final path in _sessionPaths / _lastCapturePath, so the viewer always
      // shows the same watermarked file that goes to the gallery.
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
        builder: (_) => _MediaPreviewScreen(
          mediaPath: path,
          isVideo: _lastCaptureIsVideo,
          sessionPaths: List<String>.from(_sessionPaths),
          sessionIsVideo: List<bool>.from(_sessionIsVideo),
        ),
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
                                await _watermarkService.getConfig();
                            await _watermarkService.prewarmWatermarkAssets(
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
                          height: _selectedAspectRatio == '9:16'
                              ? 260.0 + MediaQuery.of(context).padding.bottom
                              : 252.0,
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
                                      isProcessing: _isWatermarkProcessing,
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
      height: compact ? 96 : 118,
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
            height: compact ? 34 : 38,
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
  final bool isProcessing;
  final double iconRotationTurns;
  const _CircularPreview({
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

  /// All paths captured during this session (ordered oldest → newest).
  final List<String> sessionPaths;
  final List<bool> sessionIsVideo;

  const _MediaPreviewScreen({
    required this.mediaPath,
    required this.isVideo,
    this.sessionPaths = const [],
    this.sessionIsVideo = const [],
  });

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

class _MediaPreviewScreenState extends State<_MediaPreviewScreen>
    with TickerProviderStateMixin {
  // ── Video ────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  bool _isPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  Timer? _progressTimer;

  // ── Session ──────────────────────────────────────────────────────────────
  late int _activeIndex;
  late String _currentPath;
  late bool _currentIsVideo;
  late PageController _pageController;

  // ── UI chrome visibility ─────────────────────────────────────────────────
  bool _chromeVisible = true;
  Timer? _autohideTimer;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.mediaPath;
    _currentIsVideo = widget.isVideo;

    // Find the initial index in the session list (or use last if standalone).
    final idx = widget.sessionPaths.indexOf(widget.mediaPath);
    _activeIndex = idx >= 0
        ? idx
        : (widget.sessionPaths.isNotEmpty
              ? widget.sessionPaths.length - 1
              : -1);

    // PageController starts on the active item.
    _pageController = PageController(
      initialPage: _activeIndex >= 0 ? _activeIndex : 0,
    );

    _initMedia(_currentPath, _currentIsVideo);
    _scheduleAutohide();
  }

  // ── Media initialisation ─────────────────────────────────────────────────

  void _initMedia(String path, bool isVideo) {
    _disposeVideoController();
    if (!isVideo) return;

    final controller = VideoPlayerController.file(File(path));
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
      final ctrl = _videoController;
      if (ctrl == null || !mounted) return;
      setState(() {
        _videoPosition = ctrl.value.position;
        _isPlaying = ctrl.value.isPlaying;
      });
    });
  }

  // ── UI chrome ─────────────────────────────────────────────────────────────

  void _scheduleAutohide() {
    _autohideTimer?.cancel();
    _autohideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) _scheduleAutohide();
  }

  // ── Session navigation ───────────────────────────────────────────────────

  void _selectSession(int index) {
    if (index < 0 || index >= widget.sessionPaths.length) return;
    if (index == _activeIndex) return;
    setState(() {
      _activeIndex = index;
      _currentPath = widget.sessionPaths[index];
      _currentIsVideo = widget.sessionIsVideo[index];
    });
    // Animate the PageView to match.
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    _initMedia(_currentPath, _currentIsVideo);
    _scheduleAutohide();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    await SharePlus.instance.share(ShareParams(files: [XFile(_currentPath)]));
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Eliminar'),
        content: Text(
          _currentIsVideo
              ? '¿Eliminar este video? Esta acción no se puede deshacer.'
              : '¿Eliminar esta foto? Esta acción no se puede deshacer.',
        ),
        actions: [
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
      final File f = File(_currentPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    if (!mounted) return;
    // If we're in a session and more items remain, move to previous/next.
    if (widget.sessionPaths.isNotEmpty) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSystemGallery() async {
    try {
      if (Platform.isAndroid) {
        final List<AndroidIntent> intents = [
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.sec.android.gallery3d',
            flags: [268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.APP_GALLERY',
            flags: [268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.photos',
            flags: [268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.VIEW',
            type: 'image/*',
            flags: [268435456],
          ),
          const AndroidIntent(action: 'android.provider.action.PICK_IMAGES'),
        ];
        for (final intent in intents) {
          if (await _tryLaunchAndroidIntent(intent)) return;
        }
        throw Exception('No gallery intent resolved');
      }
      await Gal.open();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la galería del sistema'),
        ),
      );
    }
  }

  Future<bool> _tryLaunchAndroidIntent(AndroidIntent intent) async {
    try {
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Video controls ───────────────────────────────────────────────────────

  void _togglePlayPause() {
    final ctrl = _videoController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    HapticFeedback.selectionClick();
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    _scheduleAutohide();
    setState(() => _isPlaying = ctrl.value.isPlaying);
  }

  String _formatDuration(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _autohideTimer?.cancel();
    _progressTimer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          children: [
            // ── Main media view: carousel or single ────────────────────────
            Positioned.fill(
              child: widget.sessionPaths.length > 1
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: widget.sessionPaths.length,
                      onPageChanged: (i) {
                        final String path = widget.sessionPaths[i];
                        final bool iv = widget.sessionIsVideo[i];
                        setState(() {
                          _activeIndex = i;
                          _currentPath = path;
                          _currentIsVideo = iv;
                        });
                        _initMedia(path, iv);
                        _scheduleAutohide();
                      },
                      itemBuilder: (context, i) {
                        final String path = widget.sessionPaths[i];
                        final bool iv = widget.sessionIsVideo[i];
                        if (iv) {
                          // Video pages show the player only for the active one.
                          return i == _activeIndex
                              ? _buildVideoView()
                              : _buildVideoPlaceholder(path);
                        }
                        return _buildImagePage(path);
                      },
                    )
                  : (_currentIsVideo ? _buildVideoView() : _buildImageView()),
            ),

            // ── Bottom chrome: session strip + action bar ─────────────────
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
      actions: [
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
                    tooltip: 'Abrir galería',
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
              colors: [
                Colors.transparent,
                const Color.fromARGB(
                  0,
                  0,
                  0,
                  0,
                ).withValues(alpha: 0.30), // ← más translúcido
                const Color.fromARGB(
                  0,
                  0,
                  0,
                  0,
                ).withValues(alpha: 0.52), // ← más translúcido
              ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding + 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video progress bar
                if (_currentIsVideo) _buildVideoProgressBar(),

                // Session thumbnails strip
                if (hasSession) _buildSessionStrip(),

                const SizedBox(height: 12),

                // Action buttons row
                _buildActionBar(),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoProgressBar() {
    final double total = _videoDuration.inMilliseconds.toDouble();
    final double pos = _videoPosition.inMilliseconds.toDouble().clamp(
      0.0,
      total > 0 ? total : 1.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          // Tap to toggle play/pause
          GestureDetector(
            onTap: _togglePlayPause,
            child: Row(
              children: [
                Icon(
                  _isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(_videoPosition),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 2.5,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: pos,
                      min: 0,
                      max: total > 0 ? total : 1.0,
                      onChanged: (v) {
                        _videoController?.seekTo(
                          Duration(milliseconds: v.round()),
                        );
                        _scheduleAutohide();
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_videoDuration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStrip() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: widget.sessionPaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final bool isActive = i == _activeIndex;
          final bool iv = widget.sessionIsVideo[i];
          final String p = widget.sessionPaths[i];
          return GestureDetector(
            onTap: () => _selectSession(i),
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
                  children: [
                    if (!iv)
                      Image.file(
                        File(p),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.white12),
                      )
                    else
                      Container(color: Colors.black54),
                    if (iv)
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

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Compartir ────────────────────────────────────────────────────
          _ActionButton(
            icon: CupertinoIcons.share,
            label: 'Compartir',
            onTap: _share,
          ),

          // ── Play/Pausa (solo video) ───────────────────────────────────────
          if (_currentIsVideo)
            _ActionButton(
              icon: _isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              label: _isPlaying ? 'Pausar' : 'Reproducir',
              onTap: _togglePlayPause,
            ),

          // ── Galería ───────────────────────────────────────────────────────
          _ActionButton(
            icon: CupertinoIcons.photo_on_rectangle,
            label: 'Galería',
            onTap: _openSystemGallery,
          ),

          // ── Eliminar ─────────────────────────────────────────────────────
          _ActionButton(
            icon: CupertinoIcons.trash,
            label: 'Eliminar',
            isDestructive: true,
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  // ── Media views ───────────────────────────────────────────────────────────

  // ── Image & video pages ────────────────────────────────────────────────────

  /// Single-image page used inside the carousel.
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

  /// Thumbnail placeholder shown for video pages that are not currently active.
  Widget _buildVideoPlaceholder(String path) {
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

  Widget _buildImageView() => _buildImagePage(_currentPath);

  Widget _buildVideoView() {
    final controller = _videoController;
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
          onTap: _togglePlayPause,
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

/// Botón de acción de la barra inferior con icono + etiqueta.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructive ? const Color(0xFFFF3B30) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDestructive
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDestructive
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
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
