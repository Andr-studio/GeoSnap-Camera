import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/gps/gps_service.dart';
import '../../services/watermark/watermark_config.dart';
import '../theme/app_colors.dart';

const double defaultWatermarkCanvasWidth = 760.0;

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
    this.canvasWidth = defaultWatermarkCanvasWidth,
  });

  static Size measureSize({
    required LocationData? location,
    required WatermarkConfig config,
    required DateTime date,
    double canvasWidth = defaultWatermarkCanvasWidth,
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
    final Paint pinPaint = Paint()..color = AppColors.destructive;
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
      text: TextSpan(text: 'Google', style: fillStyle),
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
    if (config.showAddress) {
      maxTextWidth = math.max(maxTextWidth, _textWidth(addressLine, bodyStyle));
    }
    if (config.showCityCoords) {
      maxTextWidth = math.max(maxTextWidth, _textWidth(coordsLine, bodyStyle));
    }
    if (config.showDate) {
      maxTextWidth = math.max(maxTextWidth, _textWidth(dateLine, bodyStyle));
    }

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
        oldDelegate.config.mapAttributionScale != config.mapAttributionScale ||
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
