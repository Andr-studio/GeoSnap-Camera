import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:geosnap_cam/services/gps/gps_service.dart';
import 'package:geosnap_cam/services/watermark/watermark_config.dart';
import 'package:geosnap_cam/ui/painters/watermark_painter.dart';

void main() {
  group('WatermarkPainter Logic', () {
    final LocationData mockLocation = LocationData(
      latitude: 40.7128,
      longitude: -74.0060,
      address: '123 Test Street',
      city: 'Test City',
      region: 'Test Region',
      country: 'Test Country',
      countryCode: 'US',
      postalCode: '10001',
      timezone: 'America/New_York',
      temperatureC: 22.5,
      windKmh: 10.0,
      uvIndex: 5.0,
    );
    final DateTime mockDate = DateTime(2023, 10, 15, 12, 30);

    test('measureSize returns consistent dimensions for default config', () {
      final config = WatermarkConfig();
      final Size size = WatermarkPainter.measureSize(
        location: mockLocation,
        config: config,
        date: mockDate,
        canvasWidth: 760.0,
      );

      // Width and height should be calculated. We don't hardcode exact pixels
      // because fonts might render slightly differently across OS in tests,
      // but we expect it to be a valid positive size within the canvas width.
      expect(size.width, greaterThan(200)); // Minimum realistic size
      expect(size.width, lessThanOrEqualTo(760.0));
      expect(size.height, greaterThan(150));
    });

    test('measureSize shrinks width when glassWidth is reduced', () {
      final configFull = WatermarkConfig(glassWidth: 1.0);
      final configSmall = WatermarkConfig(glassWidth: 0.5);

      final Size sizeFull = WatermarkPainter.measureSize(
        location: mockLocation,
        config: configFull,
        date: mockDate,
        canvasWidth: 1000.0 * configFull.effectiveGlassWidth,
      );

      final Size sizeSmall = WatermarkPainter.measureSize(
        location: mockLocation,
        config: configSmall,
        date: mockDate,
        canvasWidth: 1000.0 * configSmall.effectiveGlassWidth,
      );

      expect(sizeSmall.width, lessThan(sizeFull.width));
    });

    test('measureSize shrinks height when elements are hidden', () {
      final configAll = WatermarkConfig(
        showAddress: true,
        showDate: true,
        showCityCoords: true,
      );
      final configHidden = WatermarkConfig(
        showAddress: false,
        showDate: false,
        showCityCoords: false,
      );

      final Size sizeAll = WatermarkPainter.measureSize(
        location: mockLocation,
        config: configAll,
        date: mockDate,
        canvasWidth: 760.0,
      );

      final Size sizeHidden = WatermarkPainter.measureSize(
        location: mockLocation,
        config: configHidden,
        date: mockDate,
        canvasWidth: 760.0,
      );

      expect(sizeHidden.height, lessThan(sizeAll.height));
    });
  });
}
