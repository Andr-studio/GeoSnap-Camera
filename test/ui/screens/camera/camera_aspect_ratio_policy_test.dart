import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geosnap_cam/ui/screens/camera/camera_aspect_ratio_policy.dart';

void main() {
  group('CameraAspectRatioPolicy', () {
    test('should cycle to the next aspect ratio correctly', () {
      // 3:4 -> 9:16
      var next = CameraAspectRatioPolicy.next(CameraAspectRatioPolicy.ratio34);
      expect(next.label, equals(CameraAspectRatioPolicy.ratio916));
      expect(
        next.cameraAspectRatio,
        equals(CameraAspectRatios.ratio_16_9),
      ); // Note: camerawesome calls it 16:9

      // 9:16 -> 1:1
      next = CameraAspectRatioPolicy.next(CameraAspectRatioPolicy.ratio916);
      expect(next.label, equals(CameraAspectRatioPolicy.ratio11));
      expect(next.cameraAspectRatio, equals(CameraAspectRatios.ratio_1_1));

      // 1:1 -> full
      next = CameraAspectRatioPolicy.next(CameraAspectRatioPolicy.ratio11);
      expect(next.label, equals(CameraAspectRatioPolicy.full));

      // full -> 3:4 (loop back)
      next = CameraAspectRatioPolicy.next(CameraAspectRatioPolicy.full);
      expect(next.label, equals(CameraAspectRatioPolicy.ratio34));
    });

    test('previewFit should return correct fit for aspect ratio', () {
      expect(
        CameraAspectRatioPolicy.previewFit(CameraAspectRatioPolicy.full),
        equals(CameraPreviewFit.cover),
      );
      expect(
        CameraAspectRatioPolicy.previewFit(CameraAspectRatioPolicy.ratio34),
        equals(CameraPreviewFit.contain),
      );
    });

    test('previewAlignment should return correct alignment for aspect ratio', () {
      expect(
        CameraAspectRatioPolicy.previewAlignment(
          CameraAspectRatioPolicy.ratio34,
        ),
        equals(Alignment.topCenter),
      );
      expect(
        CameraAspectRatioPolicy.previewAlignment(
          CameraAspectRatioPolicy.ratio916,
        ),
        equals(Alignment.center),
      );
    });
  });
}
