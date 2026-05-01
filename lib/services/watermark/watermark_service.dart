import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/error/result.dart';
import '../../data/repositories/watermark_settings_repository.dart';

import '../../ui/painters/watermark_painter.dart';
import '../gps/gps_service.dart';
import 'map_tile_service.dart';
import 'photo_watermark_processor.dart';
import 'video_watermark_processor.dart';
import 'watermark_config.dart';

export '../../ui/painters/watermark_painter.dart';
export 'watermark_config.dart';

class WatermarkService {
  final WatermarkSettingsRepository _settingsRepository;
  final MapTileService _mapTileService;

  WatermarkService({
    required WatermarkSettingsRepository settingsRepository,
    required MapTileService mapTileService,
  }) : _settingsRepository = settingsRepository,
       _mapTileService = mapTileService;

  static const double canvasWidth = 760.0;

  Future<Result<String, WatermarkFailure>> applyWatermark(
    String inputPath,
    bool isVideo,
    LocationData location, {
    String? outputPath,
  }) async {
    try {
      // ── Fase 1: paralelizar sonda de video y carga de config ──────────────
      final results = await Future.wait([
        FFprobeKit.getMediaInformation(inputPath),
        _settingsRepository.getConfig(),
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
            int rotate = 0;
            final properties = stream.getAllProperties();
            if (properties != null) {
              if (properties['tags'] is Map) {
                final tags = properties['tags'] as Map;
                if (tags.containsKey('rotate')) {
                  rotate = int.tryParse(tags['rotate'].toString()) ?? 0;
                } else if (tags.containsKey('Orientation')) {
                  final String ori = tags['Orientation'].toString();
                  if (ori == '6' || ori == '8' || ori.contains('Right') || ori.contains('Left')) {
                    rotate = 90;
                  }
                }
              }

              if (rotate == 0 && properties['side_data_list'] is List) {
                final sideDataList = properties['side_data_list'] as List;
                for (var sideData in sideDataList) {
                  if (sideData is Map && sideData.containsKey('rotation')) {
                    rotate = (double.tryParse(sideData['rotation'].toString()) ?? 0).round().abs();
                  }
                }
              }
            }

            if (rotate == 90 || rotate == 270 || rotate == -90 || rotate == -270) {
              finalW = h;
              finalH = w;
            }

            isLandscape = finalW > finalH;
            videoW = finalW;
            videoH = finalH;
            break;
          }
        }
      }

      final watermarkResult = await _createWatermarkImage(
        location,
        config,
        isLandscape,
        isVideo,
        videoWidth: videoW,
        videoHeight: videoH,
      );
      final File watermarkFile = watermarkResult.file;
      final Size watermarkSize = watermarkResult.size;

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
          config: config,
          watermarkWidth: watermarkSize.width,
          watermarkHeight: watermarkSize.height,
          videoWidth: videoW,
          videoHeight: videoH,
        );
        if (success) return Result.success(resolvedOutputPath);
        return Result.failure(const WatermarkFailure('Video encoding failed'));
      }

      final String? photoOutputPath = await PhotoWatermarkProcessor.apply(
        inputPath: inputPath,
        outputPath: resolvedOutputPath,
        watermarkFile: watermarkFile,
        config: config,
        location: location,
      );
      if (photoOutputPath != null) {
        return Result.success(photoOutputPath);
      } else {
        return Result.failure(const WatermarkFailure('Photo processing failed'));
      }
    } catch (e) {
      return Result.failure(WatermarkFailure('An unexpected error occurred: $e', exception: e is Exception ? e : null));
    }
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

  Future<({File file, Size size})> _createWatermarkImage(
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

    final double baseW = WatermarkService.canvasWidth;
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

    return (file: imgFile, size: scaledSize);
  }
}
