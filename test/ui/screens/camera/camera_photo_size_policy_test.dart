import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_photo_size_policy.dart';

void main() {
  group('CameraPhotoSizePolicy', () {
    test('should return base size and high-res size if high-res exists', () {
      final List<Size> rawSizes = <Size>[
        const Size(1920, 1080), // ~2 MP
        const Size(4000, 3000), // 12 MP (Base)
        const Size(8000, 6000), // 48 MP (High res)
      ];

      final List<Size> sorted = CameraPhotoSizePolicy.buildSortedUniqueOptions(
        rawSizes,
      );

      expect(sorted.length, equals(2));
      expect(sorted[0], equals(const Size(4000, 3000))); // baseSize
      expect(sorted[1], equals(const Size(8000, 6000))); // highResSize
    });

    test('should return only base size if no high-res size exists', () {
      final List<Size> rawSizes = <Size>[
        const Size(1920, 1080), // ~2 MP
        const Size(4000, 3000), // 12 MP (Base)
        const Size(3840, 2160), // ~8.2 MP
      ];

      final List<Size> sorted = CameraPhotoSizePolicy.buildSortedUniqueOptions(
        rawSizes,
      );

      expect(sorted.length, equals(1));
      expect(sorted[0], equals(const Size(4000, 3000))); // baseSize
    });

    test('should find default index (closest to 12 MP)', () {
      final List<Size> sizes = <Size>[
        const Size(8000, 6000), // 48 MP
        const Size(4000, 3000), // 12 MP (Closest)
        const Size(1920, 1080), // ~2 MP
      ];

      final int index = CameraPhotoSizePolicy.findDefaultIndex(sizes);
      expect(index, equals(1)); // 4000x3000
    });

    test('formatMegapixelsLabel should format rounding to nearest integer', () {
      // 4000*3000 = 12M
      final String label1 = CameraPhotoSizePolicy.formatMegapixelsLabel(
        const Size(4000, 3000),
      );
      expect(label1, equals('12M'));

      // 1920*1080 = 2.0736M -> rounds to 2M
      final String label2 = CameraPhotoSizePolicy.formatMegapixelsLabel(
        const Size(1920, 1080),
      );
      expect(label2, equals('2M'));
    });
  });
}
