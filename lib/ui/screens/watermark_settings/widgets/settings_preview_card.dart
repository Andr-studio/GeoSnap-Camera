import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geosnap_cam/services/gps/gps_service.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';

import 'watermark_settings_theme.dart';

class SettingsPreviewCard extends StatelessWidget {
  final WatermarkConfig config;
  final LocationData location;
  final ui.Image? mapImage;

  const SettingsPreviewCard({
    super.key,
    required this.config,
    required this.location,
    required this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final double canvasWidth =
        WatermarkService.canvasWidth * config.effectiveGlassWidth;
    final Size watermarkSize = WatermarkPainter.measureSize(
      location: location,
      config: config,
      date: now,
      canvasWidth: canvasWidth,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'VISTA PREVIA',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double availableWidth = constraints.maxWidth - 32;
            final double scale = math.min(
              1.0,
              availableWidth / watermarkSize.width,
            );
            final double previewWidth = watermarkSize.width * scale;
            final double previewHeight = watermarkSize.height * scale;

            return SettingsGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF121A20), Color(0xFF050708)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: CustomPaint(
                            size: watermarkSize,
                            painter: WatermarkPainter(
                              location: location,
                              config: config,
                              date: now,
                              mapImage: mapImage,
                              canvasWidth: canvasWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'La vista previa se adapta al tamano real de la marca.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
