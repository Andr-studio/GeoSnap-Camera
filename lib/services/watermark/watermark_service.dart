import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/painters/watermark_painter.dart';
import '../gps/gps_service.dart';
import 'map_tile_service.dart';
import 'photo_watermark_processor.dart';
import 'video_watermark_processor.dart';
import 'watermark_config.dart';

export '../../ui/painters/watermark_painter.dart';
export 'watermark_config.dart';

class WatermarkService {
  final SharedPreferences _prefs;
  final MapTileService _mapTileService;

  WatermarkService({
    required SharedPreferences prefs,
    required MapTileService mapTileService,
  }) : _prefs = prefs,
       _mapTileService = mapTileService;

  final ValueNotifier<WatermarkConfig> configNotifier = ValueNotifier(
    WatermarkConfig(),
  );

  static const double canvasWidth = 760.0;

  Future<String> applyWatermark(
    String inputPath,
    bool isVideo,
    LocationData location, {
    String? outputPath,
  }) async {
    try {
      // ── Fase 1: paralelizar sonda de video y carga de config ──────────────
      final results = await Future.wait([
        FFprobeKit.getMediaInformation(inputPath),
        getConfig(),
      ]);

      final sessionInfo = results[0] as dynamic;
      final WatermarkConfig config = results[1] as WatermarkConfig;

      bool isLandscape = false;
      int videoW = 1080;
      int videoH = 1920;

      final info = sessionInfo.getMediaInformation();
      if (info != null) {
        final streams = info.getStreams();
        for (var stream in streams) {
          if (stream.getType() == 'video') {
            final w = stream.getWidth() ?? 1080;
            final h = stream.getHeight() ?? 1920;
            int finalW = w;
            int finalH = h;
            final properties = stream.getAllProperties();
            if (properties != null && properties['tags'] is Map) {
              final tags = properties['tags'] as Map;
              if (tags.containsKey('rotate')) {
                final int rotate = int.tryParse(tags['rotate'].toString()) ?? 0;
                if (rotate == 90 || rotate == 270) {
                  finalW = h;
                  finalH = w;
                }
              } else if (tags.containsKey('Orientation')) {
                final String ori = tags['Orientation'].toString();
                if (ori == '6' ||
                    ori == '8' ||
                    ori.contains('Right') ||
                    ori.contains('Left')) {
                  finalW = h;
                  finalH = w;
                }
              }
            }
            isLandscape = finalW > finalH;
            videoW = finalW;
            videoH = finalH;
            break;
          }
        }
      }

      // ── Fase 2: generar marca de agua ya dimensionada al video ────────────
      final File watermarkFile = await _createWatermarkImage(
        location,
        config,
        isLandscape,
        isVideo,
        videoWidth: videoW,
        videoHeight: videoH,
      );

      // Use caller-supplied outputPath (permanent dir) or fall back to temp.
      final String resolvedOutputPath;
      if (outputPath != null && outputPath.isNotEmpty) {
        resolvedOutputPath = outputPath;
      } else {
        final Directory extDir = await getTemporaryDirectory();
        final String extension = p.extension(inputPath);
        resolvedOutputPath = p.join(
          extDir.path,
          'watermarked_${DateTime.now().millisecondsSinceEpoch}$extension',
        );
      }

      if (isVideo) {
        final bool success = await VideoWatermarkProcessor.encode(
          inputPath: inputPath,
          watermarkPath: watermarkFile.path,
          outputPath: resolvedOutputPath,
        );
        if (success) return resolvedOutputPath;
        return inputPath;
      }

      final String? photoOutputPath = await PhotoWatermarkProcessor.apply(
        inputPath: inputPath,
        outputPath: resolvedOutputPath,
        watermarkFile: watermarkFile,
        config: config,
        location: location,
      );
      return photoOutputPath ?? inputPath;
    } catch (e) {
      return inputPath;
    }
  }

  Future<WatermarkConfig> getConfig() async {
    final SharedPreferences prefs = _prefs;
    final String mapType =
        prefs.getString('wm_mapType') ?? WatermarkMapType.standard;
    final double titleScale = prefs.getDouble('wm_titleScale') ?? 0.55;
    final double textScale = prefs.getDouble('wm_textScale') ?? 0.65;
    final double glassOpacity = prefs.getDouble('wm_glassOpacity') ?? 0.55;
    final double glassWidth = prefs.getDouble('wm_glassWidth') ?? 1.0;
    final int titleColorValue =
        prefs.getInt('wm_titleColorValue') ?? 0xFFFFFFFF;
    final int textColorValue = prefs.getInt('wm_textColorValue') ?? 0xFFFFFFFF;
    final int glassColorValue =
        prefs.getInt('wm_glassColorValue') ?? 0xFF070707;
    final double mapAttributionScale =
        prefs.getDouble('wm_mapAttributionScale') ?? 1.0;
    final double mapAttributionOutlineWidth =
        prefs.getDouble('wm_mapAttributionOutlineWidth') ??
        ((prefs.getBool('wm_mapAttributionShadow') ?? true) ? 1.2 : 0.0);
    final int mapAttributionColorValue =
        prefs.getInt('wm_mapAttributionColorValue') ?? 0xFFFFFFFF;

    final WatermarkConfig config = WatermarkConfig(
      showDate: prefs.getBool('wm_showDate') ?? true,
      showAddress: prefs.getBool('wm_showAddress') ?? true,
      showCityCoords: prefs.getBool('wm_showCityCoords') ?? true,
      mapType: WatermarkMapType.values.contains(mapType)
          ? mapType
          : WatermarkMapType.standard,
      titleScale: titleScale.clamp(0.4, 1.6).toDouble(),
      textScale: textScale.clamp(0.4, 1.6).toDouble(),
      glassOpacity: glassOpacity.clamp(0.0, 1.0).toDouble(),
      glassWidth: glassWidth.clamp(0.5, 1.0).toDouble(),
      titleColorValue: titleColorValue,
      textColorValue: textColorValue,
      glassColorValue: glassColorValue,
      mapAttributionScale: mapAttributionScale.clamp(0.7, 2.2).toDouble(),
      mapAttributionOutlineWidth: mapAttributionOutlineWidth
          .clamp(0.0, 4.0)
          .toDouble(),
      mapAttributionColorValue: mapAttributionColorValue,
    );

    configNotifier.value = config;
    return config;
  }

  Future<void> saveConfig(WatermarkConfig config) async {
    // Todas las escrituras en paralelo: ~10x más rápido que secuencial.
    await Future.wait([
      _prefs.setBool('wm_showDate', config.showDate),
      _prefs.setBool('wm_showAddress', config.showAddress),
      _prefs.setBool('wm_showCityCoords', config.showCityCoords),
      _prefs.setString('wm_mapType', config.mapType),
      _prefs.setDouble('wm_titleScale', config.titleScale),
      _prefs.setDouble('wm_textScale', config.textScale),
      _prefs.setDouble('wm_glassOpacity', config.glassOpacity),
      _prefs.setDouble('wm_glassWidth', config.glassWidth),
      _prefs.setInt('wm_titleColorValue', config.titleColorValue),
      _prefs.setInt('wm_textColorValue', config.textColorValue),
      _prefs.setInt('wm_glassColorValue', config.glassColorValue),
      _prefs.setDouble('wm_mapAttributionScale', config.mapAttributionScale),
      _prefs.setDouble(
        'wm_mapAttributionOutlineWidth',
        config.mapAttributionOutlineWidth,
      ),
      _prefs.setInt(
        'wm_mapAttributionColorValue',
        config.mapAttributionColorValue,
      ),
    ]);
    configNotifier.value = config;
  }

  ui.Image? getCachedMapImage(LocationData? location, WatermarkConfig config) {
    if (location == null) return null;
    return _mapTileService.getCachedMapImage(
      latitude: location.latitude,
      longitude: location.longitude,
      mapType: config.mapType,
    );
  }

  Future<void> prewarmWatermarkAssets(
    LocationData? location,
    WatermarkConfig config,
  ) async {
    if (location == null) return;
    await _mapTileService.getOrFetchMapImage(
      latitude: location.latitude,
      longitude: location.longitude,
      mapType: config.mapType,
    );
  }

  Future<File> _createWatermarkImage(
    LocationData location,
    WatermarkConfig config,
    bool isLandscape,
    bool isVideo, {
    int videoWidth = 1080,
    int videoHeight = 1920,
  }) async {
    final DateTime now = DateTime.now();

    // Paralelizar la descarga del mapa con el resto de la preparación.
    final ui.Image? mapImage = await _mapTileService.getOrFetchMapImage(
      latitude: location.latitude,
      longitude: location.longitude,
      mapType: config.mapType,
    );

    final double baseW = isVideo && isLandscape
        ? 1013.0
        : WatermarkService.canvasWidth;
    final double canvasW = baseW * config.effectiveGlassWidth;

    final Size size = WatermarkPainter.measureSize(
      location: location,
      config: config,
      date: now,
      canvasWidth: canvasW,
    );

    // Siempre exportar a 3x para mantener calidad cuando FFmpeg/image_editor
    // escala el PNG al tamaño final. El escalado lo hace scale2ref en video.
    const double scale = 3.0;

    final Size scaledSize = size * scale;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(scale, scale);

    final WatermarkPainter painter = WatermarkPainter(
      location: location,
      config: config,
      date: now,
      mapImage: mapImage,
      canvasWidth: canvasW,
    );
    painter.paint(canvas, size);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      scaledSize.width.round().clamp(1, 8192),
      scaledSize.height.round().clamp(1, 8192),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final Directory extDir = await getTemporaryDirectory();
    final File imgFile = File(
      p.join(extDir.path, 'wm_${now.millisecondsSinceEpoch}.png'),
    );
    await imgFile.writeAsBytes(byteData!.buffer.asUint8List());

    return imgFile;
  }
}
