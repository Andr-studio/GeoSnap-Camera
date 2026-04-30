import 'package:flutter_test/flutter_test.dart';
import 'package:geosnap_cam/services/watermark/watermark_config.dart';

void main() {
  group('WatermarkConfig Tests', () {
    test('should initialize with correct default values', () {
      final config = WatermarkConfig();

      expect(config.showDate, isTrue);
      expect(config.showAddress, isTrue);
      expect(config.showCityCoords, isTrue);
      expect(config.mapType, equals(WatermarkMapType.standard));
      expect(config.titleScale, equals(0.55));
      expect(config.textScale, equals(0.65));
      expect(config.glassOpacity, equals(0.55));
      expect(config.glassWidth, equals(1.0));
      expect(config.titleColorValue, equals(0xFFFFFFFF));
      expect(config.textColorValue, equals(0xFFFFFFFF));
      expect(config.glassColorValue, equals(0xFF070707));
      expect(config.mapAttributionScale, equals(1.0));
      expect(config.mapAttributionOutlineWidth, equals(1.2));
      expect(config.mapAttributionColorValue, equals(0xFFFFFFFF));
    });

    test('effectiveGlassWidth should apply the widthScaleFactor correctly', () {
      final config1 = WatermarkConfig(glassWidth: 1.0);
      expect(
        config1.effectiveGlassWidth,
        equals(1.0 * WatermarkConfig.widthScaleFactor),
      );

      final config2 = WatermarkConfig(glassWidth: 0.5);
      expect(
        config2.effectiveGlassWidth,
        equals(0.5 * WatermarkConfig.widthScaleFactor),
      );
    });

    test('copyWith should update specified values and keep others unchanged', () {
      final original = WatermarkConfig();

      final updated = original.copyWith(
        showDate: false,
        mapType: WatermarkMapType.satellite,
        titleScale: 1.0,
      );

      // Changed values
      expect(updated.showDate, isFalse);
      expect(updated.mapType, equals(WatermarkMapType.satellite));
      expect(updated.titleScale, equals(1.0));

      // Unchanged values (should match original)
      expect(updated.showAddress, equals(original.showAddress));
      expect(updated.textScale, equals(original.textScale));
      expect(updated.glassColorValue, equals(original.glassColorValue));
    });
  });
}
