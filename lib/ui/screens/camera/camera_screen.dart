import 'dart:async';
import 'dart:io';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geosnap_cam/core/di/service_locator.dart';
import 'package:geosnap_cam/services/gps/gps_service.dart';
import 'package:geosnap_cam/data/repositories/watermark_settings_repository.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_aspect_ratio_policy.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_controller.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_focus_overlay_controller.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_media_store.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_orientation_tracker.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_photo_size_policy.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_recording_clock.dart';
import 'package:geosnap_cam/ui/screens/camera/widgets/camera_bottom_controls.dart';
import 'package:geosnap_cam/ui/screens/camera/widgets/camera_preview_overlay.dart';
import 'package:geosnap_cam/ui/screens/camera/widgets/camera_top_bar.dart';
import 'package:geosnap_cam/ui/screens/preview/media_preview_screen.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final GeoSnapCameraController _cameraController = GeoSnapCameraController();
  final ValueNotifier<int> _pinchExpandNotifier = ValueNotifier(0);
  bool _isAppInBackground = false;
  bool _isFlashMenuOpen = false;
  bool _isCameraSwitchInProgress = false;
  DateTime? _lastSwipeCameraSwitchAt;
  bool _isSingleFingerSwipeTracking = false;
  double? _singleFingerSwipeStartY;
  double? _singleFingerSwipeLastY;
  double _cameraSwitchOverlayOpacity = 0.0;
  String _selectedAspectRatio = CameraAspectRatioPolicy.ratio34;
  double _pinchLastScale = 1.0;
  String _resolutionLabel = '12M';
  bool _isDetectingPhotoSize = false;
  bool _didApplyBestPhotoSizeOnce = false;
  Timer? _focusLockTimer;
  String? _lastCapturePath;
  bool _lastCaptureIsVideo = false;
  bool _isWatermarkProcessing = false;
  final List<String> _sessionPaths = [];
  final List<bool> _sessionIsVideo = [];
  bool _gpsReadyHapticPlayed = false;
  double _iconRotationTurns = 0.0;
  static const double _singleFingerSwipeDistanceThreshold = 70.0;
  static const double _singleFingerSwipeVelocityThreshold = 700.0;
  static const Duration _cameraSwitchSwipeCooldown = Duration(
    milliseconds: 700,
  );
  static const Duration _focusLockPressDuration = Duration(seconds: 1);
  List<Size> _photoSizeOptions = <Size>[];
  int _selectedPhotoSizeIndex = -1;
  Size? _appliedPhotoSize;

  final GpsService _gpsService = appLocator<GpsService>();
  final WatermarkService _watermarkService = appLocator<WatermarkService>();
  final WatermarkSettingsRepository _settingsRepo =
      appLocator<WatermarkSettingsRepository>();
  late final CameraMediaStore _mediaStore = CameraMediaStore(
    watermarkService: _watermarkService,
  );
  final CameraOrientationTracker _orientationTracker =
      CameraOrientationTracker();
  final CameraRecordingClock _recordingClock = CameraRecordingClock();
  final CameraFocusOverlayController _focusOverlay =
      CameraFocusOverlayController();
  LocationData? _lastKnownLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request permission and start location track
    _initLocation();

    _orientationTracker.start((turns) {
      if (!mounted) return;
      setState(() {
        _iconRotationTurns = turns;
      });
    });
    // Load the GeoSnap folder so previous session files populate the strip.
    unawaited(_loadRecentSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingClock.dispose();
    _focusOverlay.dispose();
    _focusLockTimer?.cancel();
    unawaited(_orientationTracker.dispose());
    _cameraController.dispose();
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
      final WatermarkConfig config = await _settingsRepo.getConfig();
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

  Future<void> _loadRecentSession() async {
    try {
      final CameraSessionMedia session = await _mediaStore.loadRecentSession();

      if (!mounted) return;
      setState(() {
        _sessionPaths
          ..clear()
          ..addAll(session.paths);
        _sessionIsVideo
          ..clear()
          ..addAll(session.isVideos);
        if (session.paths.isNotEmpty) {
          _lastCapturePath = session.paths.last;
          _lastCaptureIsVideo = session.isVideos.last;
        }
      });
    } catch (_) {
      // Do not crash camera if session loading fails.
    }
  }

  Future<void> _switchCamera(CameraState state) async {
    await _cameraController.switchCamera(
      state,
      closeFlashMenu: _closeFlashMenu,
      onCameraSwitched: () async {
        _appliedPhotoSize = null;
        await _loadPhotoSizes(resetSelection: true);
      },
    );
  }

  void _onModeTap(int index, CameraState state) {
    _cameraController.onModeTap(
      index,
      state,
      stopRecordingClock: _stopRecordingClock,
    );
  }

  void _startRecordingClock() {
    _recordingClock.start(() {
      if (mounted) setState(() {});
    });
  }

  void _stopRecordingClock({bool reset = true}) {
    _recordingClock.stop(
      reset: reset,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _saveMediaToGallery(MediaCapture mediaCapture) async {
    if (mediaCapture.status != MediaCaptureStatus.success) return;

    if (mounted) setState(() => _isWatermarkProcessing = true);
    final SavedCameraMedia? savedMedia = await _mediaStore.saveCapture(
      mediaCapture: mediaCapture,
      location: _lastKnownLocation,
    );

    if (!mounted) return;
    setState(() {
      _isWatermarkProcessing = false;
      if (savedMedia == null) return;
      _lastCapturePath = savedMedia.path;
      if (!_sessionPaths.contains(savedMedia.path)) {
        _sessionPaths.add(savedMedia.path);
        _sessionIsVideo.add(savedMedia.isVideo);
      }
    });
  }

  void _onMediaCaptureEvent(MediaCapture mediaCapture) {
    if (mediaCapture.isVideo) {
      if (mediaCapture.status == MediaCaptureStatus.capturing &&
          mediaCapture.videoState == VideoState.started) {
        if (!_recordingClock.isRunning) {
          _startRecordingClock();
        }
      } else if (mediaCapture.status != MediaCaptureStatus.capturing ||
          mediaCapture.videoState == VideoState.stopped ||
          mediaCapture.videoState == VideoState.error) {
        _stopRecordingClock();
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
        builder: (_) => MediaPreviewScreen(
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
    final CameraAspectRatioChoice nextAspectRatio =
        CameraAspectRatioPolicy.next(_selectedAspectRatio);

    if (mounted) {
      setState(() {
        _selectedAspectRatio = nextAspectRatio.label;
      });
    }
    await state.sensorConfig.setAspectRatio(nextAspectRatio.cameraAspectRatio);
    await _loadPhotoSizes(resetSelection: false);
  }

  Future<void> _loadPhotoSizes({required bool resetSelection}) async {
    if (_isDetectingPhotoSize) return;
    _isDetectingPhotoSize = true;

    try {
      final List<Size> options = CameraPhotoSizePolicy.buildSortedUniqueOptions(
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
        nextIndex = CameraPhotoSizePolicy.findDefaultIndex(options);
      } else {
        final Size current = _photoSizeOptions[_selectedPhotoSizeIndex];
        final int found = options.indexWhere(
          (s) => s.width == current.width && s.height == current.height,
        );
        nextIndex = found >= 0
            ? found
            : CameraPhotoSizePolicy.findDefaultIndex(options);
      }

      _photoSizeOptions = options;
      _selectedPhotoSizeIndex = nextIndex;

      if (mounted) {
        setState(() {
          _resolutionLabel = CameraPhotoSizePolicy.formatMegapixelsLabel(
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
      _resolutionLabel = CameraPhotoSizePolicy.formatMegapixelsLabel(
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
    if (mounted) {
      setState(() {
        _focusOverlay.show(
          newPoint: localPosition,
          lockFocus: lock,
          showExposure: showExposureControl,
        );
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
      _focusOverlay.scheduleHide(() {
        if (mounted) setState(() {});
      });
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _setBrightness(CameraState state, double value) {
    setState(() {
      _focusOverlay.updateBrightness(value);
    });
    state.sensorConfig.setBrightness(_focusOverlay.brightness);
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
                final path = await _mediaStore.rawCapturePath('.jpg');
                return SingleCaptureRequest(path, sensors.first);
              },
              videoPathBuilder: (sensors) async {
                final path = await _mediaStore.rawCapturePath('.mp4');
                return SingleCaptureRequest(path, sensors.first);
              },
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              aspectRatio: CameraAspectRatios.ratio_4_3,
              flashMode: FlashMode.none,
            ),
            previewFit: CameraAspectRatioPolicy.previewFit(
              _selectedAspectRatio,
            ),
            previewAlignment: CameraAspectRatioPolicy.previewAlignment(
              _selectedAspectRatio,
            ),
            onMediaCaptureEvent: _onMediaCaptureEvent,
            builder: (state, preview) {
              // 👉 Escucha cuando cualquier carrusel se detiene para evitar "frenazos"
              return NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  unawaited(
                    _cameraController.applyHardwareMode(
                      state,
                      stopRecordingClock: _stopRecordingClock,
                    ),
                  );
                  return false;
                },
                child: Stack(
                  children: [
                    CameraPreviewOverlay(
                      modePageController: _cameraController.modePageController,
                      modeCount: _cameraController.modes.length,
                      onModePageChanged: _cameraController.onPageChanged,
                      onTapDown: (details, previewTouchSize) {
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
                        _focusLockTimer = Timer(_focusLockPressDuration, () {
                          unawaited(
                            _focusPreviewAt(
                              state,
                              details.localPosition,
                              previewTouchSize,
                              lock: true,
                              showExposureControl: true,
                            ),
                          );
                        });
                      },
                      onTapUp: (_) => _cancelFocusLockTimer(),
                      onTapCancel: _cancelFocusLockTimer,
                      onScaleStart: (details) =>
                          _handleZoomScaleStart(details, state),
                      onScaleUpdate: (details) =>
                          _handleZoomScaleUpdate(details, state),
                      onScaleEnd: (details) =>
                          _handleZoomScaleEnd(details, state),
                      focusPoint: _focusOverlay.point,
                      focusLocked: _focusOverlay.locked,
                      focusVisible: _focusOverlay.visible,
                      exposureVisible: _focusOverlay.exposureVisible,
                      brightness: _focusOverlay.brightness,
                      onBrightnessChanged: (value) =>
                          _setBrightness(state, value),
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
                            ? _recordingClock.label
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
                                await _settingsRepo.getConfig();
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

                    CameraBottomControls(
                      cameraState: state,
                      selectedAspectRatio: _selectedAspectRatio,
                      sensorConfig: state.sensorConfig,
                      selectedModeNotifier:
                          _cameraController.selectedModeNotifier,
                      pinchExpandNotifier: _pinchExpandNotifier,
                      bottomPageController:
                          _cameraController.bottomPageController,
                      modes: _cameraController.modes,
                      videoModeIndex: GeoSnapCameraController.videoModeIndex,
                      lastCapturePath: _lastCapturePath,
                      lastCaptureIsVideo: _lastCaptureIsVideo,
                      isWatermarkProcessing: _isWatermarkProcessing,
                      iconRotationTurns: _iconRotationTurns,
                      onLastCaptureTap: _openLastCapturePreview,
                      onSwitchCameraTap: () => _switchCamera(state),
                      onModeChanged: _cameraController.onPageChanged,
                      onModeTap: (modeIndex) => _onModeTap(modeIndex, state),
                      onShutterTap: () => _cameraController.handleShutterTap(
                        state,
                        startRecordingClock: _startRecordingClock,
                        stopRecordingClock: _stopRecordingClock,
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
