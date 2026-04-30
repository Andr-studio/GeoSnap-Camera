import 'package:flutter/material.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

class ZoomRuler extends CustomPainter {
  final double zoom;

  ZoomRuler({required this.zoom});

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
      ..color = AppColors.zoomGold
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(indicatorX, centerY - 12.5),
      Offset(indicatorX, centerY + 12.5),
      activePaint,
    );
  }

  @override
  bool shouldRepaint(ZoomRuler oldDelegate) => oldDelegate.zoom != zoom;
}
