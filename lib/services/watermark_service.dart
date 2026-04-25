import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_editor/image_editor.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gps_service.dart';

class WatermarkMapType {
  static const String standard = 'standard';
  static const String satellite = 'satellite';
  static const String terrain = 'terrain';

  static const List<String> values = <String>[standard, satellite, terrain];
}

class WatermarkConfig {
  static const double widthScaleFactor = 0.85;

  final bool showDate;
  final bool showAddress;
  final bool showCityCoords;
  final String mapType;
  final double titleScale;
  final double textScale;
  final double glassOpacity;
  final double glassWidth;
  final int titleColorValue;
  final int textColorValue;
  final int glassColorValue;
  final double mapAttributionScale;
  final double mapAttributionOutlineWidth;
  final int mapAttributionColorValue;

  WatermarkConfig({
    this.showDate = true,
    this.showAddress = true,
    this.showCityCoords = true,
    this.mapType = WatermarkMapType.standard,
    this.titleScale = 0.65,
    this.textScale = 0.65,
    this.glassOpacity = 0.0,
    this.glassWidth = 0.85,
    this.titleColorValue = 0xFFFFFFFF,
    this.textColorValue = 0xFFFFFFFF,
    this.glassColorValue = 0xFF123A55,
    this.mapAttributionScale = 1.0,
    this.mapAttributionOutlineWidth = 1.2,
    this.mapAttributionColorValue = 0xFFFFFFFF,
  });

  double get effectiveGlassWidth => glassWidth * widthScaleFactor;

  WatermarkConfig copyWith({
    bool? showDate,
    bool? showAddress,
    bool? showCityCoords,
    String? mapType,
    double? titleScale,
    double? textScale,
    double? glassOpacity,
    double? glassWidth,
    int? titleColorValue,
    int? textColorValue,
    int? glassColorValue,
    double? mapAttributionScale,
    double? mapAttributionOutlineWidth,
    int? mapAttributionColorValue,
  }) {
    return WatermarkConfig(
      showDate: showDate ?? this.showDate,
      showAddress: showAddress ?? this.showAddress,
      showCityCoords: showCityCoords ?? this.showCityCoords,
      mapType: mapType ?? this.mapType,
      titleScale: titleScale ?? this.titleScale,
      textScale: textScale ?? this.textScale,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassWidth: glassWidth ?? this.glassWidth,
      titleColorValue: titleColorValue ?? this.titleColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      glassColorValue: glassColorValue ?? this.glassColorValue,
      mapAttributionScale: mapAttributionScale ?? this.mapAttributionScale,
      mapAttributionOutlineWidth:
          mapAttributionOutlineWidth ?? this.mapAttributionOutlineWidth,
      mapAttributionColorValue:
          mapAttributionColorValue ?? this.mapAttributionColorValue,
    );
  }
}

class WatermarkService {
  static final ValueNotifier<WatermarkConfig> configNotifier = ValueNotifier(
    WatermarkConfig(),
  );

  static const double canvasWidth = 760.0;
  static const int _mapZoom = 16;
  static final Map<String, ui.Image> _mapCache = <String, ui.Image>{};

  static Future<String> applyWatermark(
    String inputPath,
    bool isVideo,
    LocationData location,
  ) async {
    try {
      bool isLandscape = false;
      final sessionInfo = await FFprobeKit.getMediaInformation(inputPath);
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
            break;
          }
        }
      }

      final WatermarkConfig config = await getConfig();
      final File watermarkFile = await _createWatermarkImage(
        location,
        config,
        isLandscape,
        isVideo,
      );

      final Directory extDir = await getTemporaryDirectory();
      final String extension = p.extension(inputPath);
      final String outputPath = p.join(
        extDir.path,
        'watermarked_${DateTime.now().millisecondsSinceEpoch}$extension',
      );

      if (isVideo) {
        final String command =
            '-y -i "$inputPath" -i "${watermarkFile.path}" '
            "-filter_complex \"[1:v][0:v]scale2ref=w='main_w*min(iw,ih)/2280':h='main_h*min(iw,ih)/2280'[wm][vid];[vid][wm]overlay=(W-w)/2:H-h-(H*0.02)[out]\" "
            '-map "[out]" -map 0:a? -c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) return outputPath;
        print('FFMPEG ERROR VIDEO: ${await session.getOutput()}');
        return inputPath;
      }

      final String? photoOutputPath = await _applyPhotoWatermarkWithImageEditor(
        inputPath: inputPath,
        outputPath: outputPath,
        watermarkFile: watermarkFile,
        config: config,
      );
      return photoOutputPath ?? inputPath;
    } catch (e) {
      print('WATERMARK EXCEPTION: $e');
      return inputPath;
    }
  }

  static Future<WatermarkConfig> getConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String mapType =
        prefs.getString('wm_mapType') ?? WatermarkMapType.standard;
    final double titleScale = prefs.getDouble('wm_titleScale') ?? 0.65;
    final double textScale = prefs.getDouble('wm_textScale') ?? 0.65;
    final double glassOpacity = prefs.getDouble('wm_glassOpacity') ?? 0.0;
    final double glassWidth = prefs.getDouble('wm_glassWidth') ?? 0.85;
    final int titleColorValue =
        prefs.getInt('wm_titleColorValue') ?? 0xFFFFFFFF;
    final int textColorValue = prefs.getInt('wm_textColorValue') ?? 0xFFFFFFFF;
    final int glassColorValue =
        prefs.getInt('wm_glassColorValue') ?? 0xFF123A55;
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
      mapAttributionOutlineWidth:
          mapAttributionOutlineWidth.clamp(0.0, 4.0).toDouble(),
      mapAttributionColorValue: mapAttributionColorValue,
    );

    configNotifier.value = config;
    return config;
  }

  static Future<void> saveConfig(WatermarkConfig config) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wm_showDate', config.showDate);
    await prefs.setBool('wm_showAddress', config.showAddress);
    await prefs.setBool('wm_showCityCoords', config.showCityCoords);
    await prefs.setString('wm_mapType', config.mapType);
    await prefs.setDouble('wm_titleScale', config.titleScale);
    await prefs.setDouble('wm_textScale', config.textScale);
    await prefs.setDouble('wm_glassOpacity', config.glassOpacity);
    await prefs.setDouble('wm_glassWidth', config.glassWidth);
    await prefs.setInt('wm_titleColorValue', config.titleColorValue);
    await prefs.setInt('wm_textColorValue', config.textColorValue);
    await prefs.setInt('wm_glassColorValue', config.glassColorValue);
    await prefs.setDouble(
      'wm_mapAttributionScale',
      config.mapAttributionScale,
    );
    await prefs.setDouble(
      'wm_mapAttributionOutlineWidth',
      config.mapAttributionOutlineWidth,
    );
    await prefs.setInt(
      'wm_mapAttributionColorValue',
      config.mapAttributionColorValue,
    );
    configNotifier.value = config;
  }

  static ui.Image? getCachedMapImage(
    LocationData? location,
    WatermarkConfig config,
  ) {
    if (location == null) return null;
    final _TileCoord tile = _latLonToTile(
      location.latitude,
      location.longitude,
      _mapZoom,
    );
    return _mapCache[_cacheKey(config.mapType, tile.x, tile.y, _mapZoom)];
  }

  static Future<void> prewarmWatermarkAssets(
    LocationData? location,
    WatermarkConfig config,
  ) async {
    if (location == null) return;
    await _getOrFetchMapImage(
      latitude: location.latitude,
      longitude: location.longitude,
      mapType: config.mapType,
    );
  }

  static double _photoOverlayWidthFactor(WatermarkConfig config) {
    return config.effectiveGlassWidth.clamp(0.42, 0.76).toDouble();
  }

  static Future<String?> _applyPhotoWatermarkWithImageEditor({
    required String inputPath,
    required String outputPath,
    required File watermarkFile,
    required WatermarkConfig config,
  }) async {
    try {
      final File inputFile = File(inputPath);
      final Uint8List photoBytes = await inputFile.readAsBytes();
      final Uint8List watermarkBytes = await watermarkFile.readAsBytes();
      final ui.Image photoImage = await _decodeImage(photoBytes);
      final ui.Image watermarkImage = await _decodeImage(watermarkBytes);

      final int targetWidth =
          (photoImage.width * _photoOverlayWidthFactor(config)).round();
      final int targetHeight =
          (targetWidth * watermarkImage.height / watermarkImage.width).round();
      final int safeWidth = targetWidth.clamp(1, photoImage.width);
      final int safeHeight = targetHeight.clamp(1, photoImage.height);
      final int x = ((photoImage.width - safeWidth) / 2).round();
      final int y = (photoImage.height - safeHeight - (photoImage.height * 0.02))
          .round()
          .clamp(0, photoImage.height - safeHeight);

      final ImageEditorOption option = ImageEditorOption()
        ..outputFormat = const OutputFormat.jpeg(95)
        ..addOption(
          MixImageOption(
            target: ImageSource.memory(watermarkBytes),
            x: x,
            y: y,
            width: safeWidth,
            height: safeHeight,
          ),
        );

      final Uint8List? result = await ImageEditor.editFileImage(
        file: inputFile,
        imageEditorOption: option,
      );
      if (result == null || result.isEmpty) return null;

      await File(outputPath).writeAsBytes(result, flush: true);
      return outputPath;
    } catch (e) {
      print('IMAGE_EDITOR PHOTO WATERMARK ERROR: $e');
      return null;
    }
  }

  static Future<File> _createWatermarkImage(
    LocationData location,
    WatermarkConfig config,
    bool isLandscape,
    bool isVideo,
  ) async {
    final DateTime now = DateTime.now();
    final ui.Image? mapImage = await _getOrFetchMapImage(
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

    final double scale =
        3.0; // Export at 3x resolution for high quality when scaling up
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
      scaledSize.width.toInt(),
      scaledSize.height.toInt(),
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

  static Future<ui.Image?> _getOrFetchMapImage({
    required double latitude,
    required double longitude,
    required String mapType,
  }) async {
    final _TileCoord tile = _latLonToTile(latitude, longitude, _mapZoom);
    final String key = _cacheKey(mapType, tile.x, tile.y, _mapZoom);
    final ui.Image? cached = _mapCache[key];
    if (cached != null) return cached;

    try {
      final Uri uri = _buildTileUri(
        mapType: mapType,
        x: tile.x,
        y: tile.y,
        z: _mapZoom,
      );
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final ui.Image image = await _decodeImage(response.bodyBytes);
      _mapCache[key] = image;

      if (_mapCache.length > 60) {
        _mapCache.remove(_mapCache.keys.first);
      }

      return image;
    } catch (_) {
      return null;
    }
  }

  static String _cacheKey(String mapType, int x, int y, int z) {
    return '$mapType:$z:$x:$y';
  }

  static Uri _buildTileUri({
    required String mapType,
    required int x,
    required int y,
    required int z,
  }) {
    switch (mapType) {
      case WatermarkMapType.satellite:
        return Uri.parse(
          'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x',
        );
      case WatermarkMapType.terrain:
        return Uri.parse('https://a.tile.opentopomap.org/$z/$x/$y.png');
      case WatermarkMapType.standard:
      default:
        return Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
    }
  }

  static _TileCoord _latLonToTile(double lat, double lon, int zoom) {
    final double clampedLat = lat.clamp(-85.0511, 85.0511);
    final double n = math.pow(2.0, zoom).toDouble();
    final int x = (((lon + 180.0) / 360.0) * n).floor();
    final double latRad = clampedLat * math.pi / 180.0;
    final int y =
        ((1.0 -
                    math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) /
                        math.pi) /
                2.0 *
                n)
            .floor();

    final int maxTile = n.toInt() - 1;
    return _TileCoord(x: x.clamp(0, maxTile), y: y.clamp(0, maxTile));
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}

class _TileCoord {
  final int x;
  final int y;

  const _TileCoord({required this.x, required this.y});
}

class WatermarkPainter extends CustomPainter {
  final LocationData? location;
  final WatermarkConfig config;
  final DateTime date;
  final ui.Image? mapImage;
  final double canvasWidth;

  static const double _padding = 22.0;
  static const double _horizontalGap = 18.0;

  WatermarkPainter({
    required this.location,
    required this.config,
    required this.date,
    this.mapImage,
    this.canvasWidth = WatermarkService.canvasWidth,
  });

  static Size measureSize({
    required LocationData? location,
    required WatermarkConfig config,
    required DateTime date,
    double canvasWidth = WatermarkService.canvasWidth,
  }) {
    final _MeasuredLayout m = _measure(
      location: location,
      config: config,
      date: date,
      maxWidth: canvasWidth,
    );
    return Size(m.actualTotalWidth, m.totalHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _MeasuredLayout measured = _measure(
      location: location,
      config: config,
      date: date,
      maxWidth: canvasWidth,
    );

    final double offsetX = (size.width - measured.actualTotalWidth) / 2.0;
    if (offsetX > 0) {
      canvas.translate(offsetX, 0);
    }

    final RRect glassRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, measured.actualTotalWidth, measured.totalHeight),
      const Radius.circular(24),
    );
    final Color glassColor = Color(config.glassColorValue);
    final double glassAlpha = config.glassOpacity.clamp(0.0, 1.0).toDouble();
    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          glassColor.withValues(alpha: glassAlpha * 0.62),
          Colors.black.withValues(alpha: glassAlpha * 0.72),
          glassColor.withValues(alpha: glassAlpha * 0.36),
        ],
        [0.0, 0.52, 1.0],
      )
      ..style = PaintingStyle.fill;

    final Paint waterGlowPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(measured.actualTotalWidth, measured.totalHeight),
        [
          Colors.white.withValues(alpha: glassAlpha * 0.20),
          glassColor.withValues(alpha: glassAlpha * 0.12),
          Colors.transparent,
        ],
        [0.0, 0.36, 1.0],
      )
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: glassAlpha * 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(glassRRect, bgPaint);
    canvas.drawRRect(glassRRect, waterGlowPaint);
    canvas.drawRRect(glassRRect, borderPaint);

    final Rect mapRect = Rect.fromLTWH(
      _padding,
      _padding,
      measured.mapWidth,
      measured.innerHeight,
    );
    _drawMap(canvas, mapRect);

    final double contentX = _padding + measured.mapWidth + _horizontalGap;
    final double textMaxWidth = measured.contentWidth;
    double y = _padding;

    y = _paintParagraph(
      canvas,
      text: measured.title,
      style: measured.titleStyle,
      x: contentX,
      y: y,
      maxWidth: textMaxWidth,
    );

    y += measured.titleDividerGap;
    final Paint dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(contentX, y),
      Offset(contentX + textMaxWidth, y),
      dividerPaint,
    );
    y += measured.titleDividerGap;

    if (config.showAddress) {
      y = _paintParagraph(
        canvas,
        text: measured.addressLine,
        style: measured.bodyStyle,
        x: contentX,
        y: y,
        maxWidth: textMaxWidth,
      );
      y += measured.lineGap;
    }

    if (config.showCityCoords) {
      y = _paintParagraph(
        canvas,
        text: measured.coordsLine,
        style: measured.bodyStyle,
        x: contentX,
        y: y,
        maxWidth: textMaxWidth,
      );
      y += measured.lineGap;
    }

    if (config.showDate) {
      y = _paintParagraph(
        canvas,
        text: measured.dateLine,
        style: measured.bodyStyle,
        x: contentX,
        y: y,
        maxWidth: textMaxWidth,
      );
    }

    final double weatherTop =
        _padding + measured.innerHeight - measured.weatherRowHeight;

    canvas.drawLine(
      Offset(contentX, weatherTop - measured.weatherDividerGap),
      Offset(contentX + textMaxWidth, weatherTop - measured.weatherDividerGap),
      dividerPaint,
    );

    _drawMetricRow(
      canvas,
      contentX: contentX,
      y: weatherTop,
      maxWidth: textMaxWidth,
      measured: measured,
    );
  }

  void _drawMap(Canvas canvas, Rect rect) {
    final RRect mapRRect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(16),
    );

    canvas.save();
    canvas.clipRRect(mapRRect);

    if (mapImage != null) {
      final Rect src = Rect.fromLTWH(
        0,
        0,
        mapImage!.width.toDouble(),
        mapImage!.height.toDouble(),
      );
      canvas.drawImageRect(mapImage!, src, rect, Paint());
    } else {
      final Paint fallbackPaint = Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF4A545F), Color(0xFF232B36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawRect(rect, fallbackPaint);

      final Paint linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1;
      for (int i = 1; i < 6; i++) {
        final double dx = rect.left + (rect.width / 6) * i;
        final double dy = rect.top + (rect.height / 6) * i;
        canvas.drawLine(
          Offset(dx, rect.top),
          Offset(dx, rect.bottom),
          linePaint,
        );
        canvas.drawLine(
          Offset(rect.left, dy),
          Offset(rect.right, dy),
          linePaint,
        );
      }
    }

    _drawMapAttribution(canvas, rect);

    final Offset center = Offset(rect.center.dx, rect.center.dy);
    final Paint pinPaint = Paint()..color = const Color(0xFFFF3B30);
    canvas.drawCircle(center, 10, pinPaint);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);

    canvas.restore();
  }

  void _drawMapAttribution(Canvas canvas, Rect rect) {
    final Color color = Color(config.mapAttributionColorValue);
    final double scale = config.mapAttributionScale.clamp(0.7, 2.2).toDouble();
    final double outlineWidth = config.mapAttributionOutlineWidth
        .clamp(0.0, 4.0)
        .toDouble();
    final TextStyle fillStyle = TextStyle(
      color: color,
      fontSize: 13 * scale,
      fontWeight: FontWeight.w700,
      fontFamily: 'Roboto',
    );
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'Google',
        style: fillStyle,
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout();

    final Rect labelBg = Rect.fromLTWH(
      rect.left + 8,
      rect.bottom - tp.height - 9,
      tp.width + (10 * scale),
      tp.height + (4 * scale),
    );
    final Offset textOffset = Offset(
      labelBg.left + (5 * scale),
      labelBg.top + (2 * scale),
    );

    if (outlineWidth > 0) {
      final TextPainter outlineTp = TextPainter(
        text: TextSpan(
          text: 'Google',
          style: TextStyle(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth * scale
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
            fontSize: 13 * scale,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      );
      outlineTp.layout();
      outlineTp.paint(canvas, textOffset);
    }
    tp.paint(canvas, textOffset);
  }

  double _paintParagraph(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required double x,
    required double y,
    required double maxWidth,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: null,
    );
    tp.layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
    return y + tp.height;
  }

  void _drawMetricRow(
    Canvas canvas, {
    required double contentX,
    required double y,
    required double maxWidth,
    required _MeasuredLayout measured,
  }) {
    final List<String> metrics = <String>[
      '☁️ ${measured.temperatureLabel}',
      '💨 ${measured.windLabel}',
      '☀️ UV ${measured.uvLabel}',
    ];

    final double eachWidth = maxWidth / 3;
    for (int i = 0; i < metrics.length; i++) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: metrics[i], style: measured.metricStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );
      tp.layout(maxWidth: eachWidth - 6);
      tp.paint(canvas, Offset(contentX + eachWidth * i, y));
    }
  }

  static double _textWidth(String text, TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    return tp.width;
  }

  static _MeasuredLayout _measure({
    required LocationData? location,
    required WatermarkConfig config,
    required DateTime date,
    required double maxWidth,
  }) {
    final LocationData? safeLocation = location;
    final String region = _safeText(safeLocation?.region);
    final String city = _safeText(safeLocation?.city);
    final String country = _safeText(safeLocation?.country);
    final String countryCode = _safeText(safeLocation?.countryCode);

    final String title = _buildTitle(
      region: region,
      city: city,
      country: country,
      countryCode: countryCode,
    );

    final String addressLine = _buildAddressLine(safeLocation);
    final String coordsLine =
        '🎯 Lat ${_coordValue(safeLocation?.latitude)}, Long ${_coordValue(safeLocation?.longitude)}';

    final String timezoneLabel = _timezoneLabel(
      safeLocation?.timezone ?? '',
      date.timeZoneOffset,
    );
    final String dateLine =
        '🕒 ${_dateLabel(date, countryCode)}  $timezoneLabel';

    final double titleS = config.titleScale.clamp(0.4, 1.6).toDouble();
    final double s = config.textScale.clamp(0.4, 1.6).toDouble();
    final double layoutS = math.max(titleS, s);
    final Color titleColor = Color(config.titleColorValue);
    final Color textColor = Color(config.textColorValue);
    final TextStyle titleStyle = TextStyle(
      color: titleColor,
      fontSize: 44 * titleS,
      fontWeight: FontWeight.w700,
      fontFamily: 'Roboto',
      height: 1.08,
    );
    final TextStyle bodyStyle = TextStyle(
      color: textColor.withValues(alpha: 0.94),
      fontSize: 28 * s,
      fontWeight: FontWeight.w500,
      fontFamily: 'Roboto',
      height: 1.2,
    );
    final TextStyle metricStyle = TextStyle(
      color: textColor,
      fontSize: 32 * s,
      fontWeight: FontWeight.w600,
      fontFamily: 'Roboto',
      height: 1.0,
    );

    final double mapWidth = 176;
    final double maxAllowedContentWidth =
        maxWidth - _padding - mapWidth - _horizontalGap - _padding;

    double maxTextWidth = 0;
    maxTextWidth = math.max(maxTextWidth, _textWidth(title, titleStyle));
    if (config.showAddress)
      maxTextWidth = math.max(maxTextWidth, _textWidth(addressLine, bodyStyle));
    if (config.showCityCoords)
      maxTextWidth = math.max(maxTextWidth, _textWidth(coordsLine, bodyStyle));
    if (config.showDate)
      maxTextWidth = math.max(maxTextWidth, _textWidth(dateLine, bodyStyle));

    final double weatherDividerGap = 10 * s;
    final double weatherWidth =
        (_textWidth('? --.- °C', metricStyle) * 3) + (weatherDividerGap * 2);
    maxTextWidth = math.max(maxTextWidth, weatherWidth);

    final double contentWidth = math.min(maxTextWidth, maxAllowedContentWidth);
    final double actualTotalWidth =
        _padding + mapWidth + _horizontalGap + contentWidth + _padding;

    final double titleDividerGap = 10 * layoutS;
    final double lineGap = 5 * s;

    double textBlockHeight = 0;
    textBlockHeight += _textHeight(title, titleStyle, contentWidth);
    textBlockHeight += (titleDividerGap * 2) + 1;

    if (config.showAddress) {
      textBlockHeight += _textHeight(addressLine, bodyStyle, contentWidth);
      textBlockHeight += lineGap;
    }
    if (config.showCityCoords) {
      textBlockHeight += _textHeight(coordsLine, bodyStyle, contentWidth);
      textBlockHeight += lineGap;
    }
    if (config.showDate) {
      textBlockHeight += _textHeight(dateLine, bodyStyle, contentWidth);
    }

    final double weatherRowHeight =
        _textHeight('? --.- °C', metricStyle, contentWidth / 3) + 2;

    final double rightMinHeight =
        textBlockHeight + (weatherDividerGap * 2) + weatherRowHeight + 4;
    final double innerHeight = math.max(190 * layoutS, rightMinHeight);
    final double totalHeight = innerHeight + (_padding * 2);

    return _MeasuredLayout(
      title: title,
      addressLine: addressLine,
      coordsLine: coordsLine,
      dateLine: dateLine,
      titleStyle: titleStyle,
      bodyStyle: bodyStyle,
      metricStyle: metricStyle,
      mapWidth: mapWidth,
      contentWidth: contentWidth,
      titleDividerGap: titleDividerGap,
      lineGap: lineGap,
      weatherDividerGap: weatherDividerGap,
      weatherRowHeight: weatherRowHeight,
      innerHeight: innerHeight,
      totalHeight: totalHeight,
      actualTotalWidth: actualTotalWidth,
      temperatureLabel: _temperatureLabel(safeLocation),
      windLabel: _windLabel(safeLocation),
      uvLabel: _uvLabel(safeLocation),
    );
  }

  static double _textHeight(String text, TextStyle style, double maxWidth) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: null,
    );
    tp.layout(maxWidth: maxWidth);
    return tp.height;
  }

  static String _safeText(String? value) {
    return value == null ? '' : value.trim();
  }

  static String _buildTitle({
    required String region,
    required String city,
    required String country,
    required String countryCode,
  }) {
    final List<String> parts = <String>[];
    final Map<String, int> repeatedPlaceCounts = <String, int>{};

    _appendTitlePlaceParts(parts, repeatedPlaceCounts, city);
    _appendTitlePlaceParts(parts, repeatedPlaceCounts, region);
    if (country.isNotEmpty) parts.add(country);

    final String fallback = parts.isEmpty ? 'Ubicación GPS' : parts.join(', ');
    final String flag = _flagEmoji(countryCode);
    return flag.isEmpty ? fallback : '$fallback $flag';
  }

  static void _appendTitlePlaceParts(
    List<String> parts,
    Map<String, int> repeatedPlaceCounts,
    String value,
  ) {
    for (final String rawPart in value.split(',')) {
      final String part = rawPart.trim();
      if (part.isEmpty) continue;

      final String key = part.toLowerCase();
      final int count = repeatedPlaceCounts[key] ?? 0;
      if (count >= 2) continue;

      parts.add(part);
      repeatedPlaceCounts[key] = count + 1;
    }
  }

  static String _buildAddressLine(LocationData? location) {
    if (location == null) return '📍 Dirección no disponible';
    final List<String> parts = <String>[
      if (location.address.trim().isNotEmpty) location.address.trim(),
      if (location.postalCode.trim().isNotEmpty) location.postalCode.trim(),
      if (location.city.trim().isNotEmpty) location.city.trim(),
      if (location.country.trim().isNotEmpty) location.country.trim(),
    ];
    if (parts.isEmpty) return '📍 Dirección no disponible';
    return '📍 ${parts.join(', ')}';
  }

  static String _coordValue(double? value) {
    if (value == null) return '--.------';
    return value.toStringAsFixed(6);
  }

  static String _dateLabel(DateTime date, String countryCode) {
    final bool isEnglish = [
      'US',
      'GB',
      'AU',
      'CA',
      'NZ',
      'IE',
    ].contains(countryCode.trim().toUpperCase());
    final List<String> daysEs = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final List<String> daysEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final String dayName = isEnglish
        ? daysEn[date.weekday - 1]
        : daysEs[date.weekday - 1];
    final DateFormat formatter = DateFormat('dd/MM/yyyy h:mm a');
    return '$dayName, ${formatter.format(date)}';
  }

  static String _timezoneLabel(String timezone, Duration offset) {
    final String gmt = _offsetLabel(offset);
    if (timezone.trim().isEmpty) return gmt;
    return '${timezone.trim()}  $gmt';
  }

  static String _offsetLabel(Duration offset) {
    final String sign = offset.isNegative ? '-' : '+';
    final Duration absOffset = offset.abs();
    final String h = absOffset.inHours.toString().padLeft(2, '0');
    final String m = (absOffset.inMinutes % 60).toString().padLeft(2, '0');
    return 'GMT $sign$h:$m';
  }

  static String _temperatureLabel(LocationData? location) {
    final double? value = location?.temperatureC;
    if (value == null) return '--.- °C';
    return '${value.toStringAsFixed(1)} °C';
  }

  static String _windLabel(LocationData? location) {
    final double? value = location?.windKmh;
    if (value == null) return '--.- km/h';
    return '${value.toStringAsFixed(1)} km/h';
  }

  static String _uvLabel(LocationData? location) {
    final double? value = location?.uvIndex;
    if (value == null) return '--.-';
    return value.toStringAsFixed(1);
  }

  static String _flagEmoji(String countryCode) {
    final String normalized = countryCode.trim().toUpperCase();
    if (normalized.length != 2) return '';
    final int first = normalized.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = normalized.codeUnitAt(1) - 0x41 + 0x1F1E6;
    if (first < 0x1F1E6 || first > 0x1F1FF) return '';
    if (second < 0x1F1E6 || second > 0x1F1FF) return '';
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.location != location ||
        oldDelegate.config.showDate != config.showDate ||
        oldDelegate.config.showAddress != config.showAddress ||
        oldDelegate.config.showCityCoords != config.showCityCoords ||
        oldDelegate.config.mapType != config.mapType ||
        oldDelegate.config.titleScale != config.titleScale ||
        oldDelegate.config.textScale != config.textScale ||
        oldDelegate.config.glassOpacity != config.glassOpacity ||
        oldDelegate.config.glassWidth != config.glassWidth ||
        oldDelegate.config.titleColorValue != config.titleColorValue ||
        oldDelegate.config.textColorValue != config.textColorValue ||
        oldDelegate.config.glassColorValue != config.glassColorValue ||
        oldDelegate.config.mapAttributionScale !=
            config.mapAttributionScale ||
        oldDelegate.config.mapAttributionOutlineWidth !=
            config.mapAttributionOutlineWidth ||
        oldDelegate.config.mapAttributionColorValue !=
            config.mapAttributionColorValue ||
        oldDelegate.date.minute != date.minute ||
        oldDelegate.mapImage != mapImage;
  }
}

class _MeasuredLayout {
  final String title;
  final String addressLine;
  final String coordsLine;
  final String dateLine;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle metricStyle;
  final double mapWidth;
  final double contentWidth;
  final double titleDividerGap;
  final double lineGap;
  final double weatherDividerGap;
  final double weatherRowHeight;
  final double innerHeight;
  final double totalHeight;
  final double actualTotalWidth;
  final String temperatureLabel;
  final String windLabel;
  final String uvLabel;

  const _MeasuredLayout({
    required this.title,
    required this.addressLine,
    required this.coordsLine,
    required this.dateLine,
    required this.titleStyle,
    required this.bodyStyle,
    required this.metricStyle,
    required this.mapWidth,
    required this.contentWidth,
    required this.titleDividerGap,
    required this.lineGap,
    required this.weatherDividerGap,
    required this.weatherRowHeight,
    required this.innerHeight,
    required this.totalHeight,
    required this.actualTotalWidth,
    required this.temperatureLabel,
    required this.windLabel,
    required this.uvLabel,
  });
}
