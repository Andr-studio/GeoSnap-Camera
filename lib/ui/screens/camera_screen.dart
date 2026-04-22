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

class _CameraScreenState extends State<CameraScreen> {
  final List<String> _modes = ['Retrato', 'Imagen', 'Video'];
  int _selectedModeIndex = 1;

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

  // 👉 Lógica corregida: Usamos el método oficial y seguro del paquete
  void _switchCamera(CameraState state) {
    state.switchCameraSensor();
  }

  // 👉 Lógica centralizada para cambiar el modo de cámara
  void _setMode(int index, CameraState state) {
    if (index == _selectedModeIndex) return;
    
    HapticFeedback.lightImpact(); // Vibración premium
    setState(() {
      _selectedModeIndex = index;
      if (index == 0) { // Retrato
        state.setState(CaptureMode.photo);
      } else if (index == 1) { // Imagen
        state.setState(CaptureMode.photo);
      } else if (index == 2) { // Video
        state.setState(CaptureMode.video);
      }
    });
  }

  // 👉 Detector de deslizamiento horizontal sobre la vista de cámara
  void _onSwipe(DragEndDetails details, CameraState state) {
    int newIndex = _selectedModeIndex;

    // Si la velocidad del deslizamiento es alta hacia la derecha o izquierda
    if (details.primaryVelocity! > 300) {
      newIndex--; // Deslizamiento a la derecha (modo anterior)
    } else if (details.primaryVelocity! < -300) {
      newIndex++; // Deslizamiento a la izquierda (modo siguiente)
    }

    // Aplicar el cambio si está dentro de los límites
    if (newIndex >= 0 &&
        newIndex < _modes.length &&
        newIndex != _selectedModeIndex) {
      _setMode(newIndex, state);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el padding inferior del sistema
    final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraAwesomeBuilder.custom(
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
        previewFit: CameraPreviewFit.fitWidth,
        builder: (state, preview) {
          // 👉 Envolvemos el Stack principal en un GestureDetector
          return GestureDetector(
            onHorizontalDragEnd: (details) => _onSwipe(details, state),
            child: Stack(
              children: [
                // 1. Top Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CameraTopBar(
                    flashMode: state.sensorConfig.flashMode.name,
                    onFlashToggle: () {
                      final current = state.sensorConfig.flashMode;
                      if (current == FlashMode.none) {
                        state.sensorConfig.setFlashMode(FlashMode.on);
                      } else if (current == FlashMode.on) {
                        state.sensorConfig.setFlashMode(FlashMode.auto);
                      } else {
                        state.sensorConfig.setFlashMode(FlashMode.none);
                      }
                      setState(() {});
                    },
                    onSettingsTap: () {
                      // TODO: Show settings
                    },
                  ),
                ),

                // 3. Bottom Controls Area (One UI 8.5 Layout)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      height: 220, // Aumentado para acomodar la nueva jerarquía
                      color: Colors.black,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 1. Zoom Selector (Ahora aquí para mejor ergonomía)
                          _ZoomSelector(
                            onZoomChanged: (zoom) {
                              state.sensorConfig.setZoom(zoom);
                            },
                          ),

                          // 2. Main Row (Shutter, Gallery, Flip)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CircularPreview(onTap: () {
                                  // TODO: Open Gallery
                                }),
                                ShutterButton(
                                  isVideoMode: _selectedModeIndex == 2,
                                  isRecording: state is VideoRecordingCameraState,
                                  onTap: () {
                                    state.when(
                                      onPhotoMode: (s) => s.takePhoto(),
                                      onVideoMode: (s) => s.startRecording(),
                                      onVideoRecordingMode: (s) => s.stopRecording(),
                                      onPreviewMode: (s) {
                                        // Default behavior
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

                          // 3. Mode Selector (En la base, estilo One UI)
                          ShaderMask(
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
                            child: CameraModeSelector(
                              modes: _modes,
                              selectedIndex: _selectedModeIndex,
                              onModeChanged: (index) => _setMode(index, state),
                            ),
                          ),
                          const SizedBox(height: 5), // Pequeño margen final
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
    );
  }
}

class _ZoomSelector extends StatefulWidget {
  final Function(double) onZoomChanged;

  const _ZoomSelector({required this.onZoomChanged});

  @override
  State<_ZoomSelector> createState() => _ZoomSelectorState();
}

class _ZoomSelectorState extends State<_ZoomSelector> {
  double _currentZoom = 0.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomBtn('.5', 0.0),
              _zoomBtn('1x', 0.3),
              _zoomBtn('2', 0.6),
              _zoomBtn('3', 1.0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomBtn(String label, double value) {
    final bool isSelected = _currentZoom == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick(); // Vibración al elegir zoom
        setState(() => _currentZoom = value);
        widget.onZoomChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
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

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircularIconButton({required this.icon, required this.onTap});

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
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
