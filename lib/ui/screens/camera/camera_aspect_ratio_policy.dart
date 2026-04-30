import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/widgets.dart';

class CameraAspectRatioChoice {
  final String label;
  final CameraAspectRatios cameraAspectRatio;

  const CameraAspectRatioChoice({
    required this.label,
    required this.cameraAspectRatio,
  });
}

class CameraAspectRatioPolicy {
  static const String ratio34 = '3:4';
  static const String ratio916 = '9:16';
  static const String ratio11 = '1:1';
  static const String full = 'Full';

  static CameraAspectRatioChoice next(String current) {
    switch (current) {
      case ratio34:
        return const CameraAspectRatioChoice(
          label: ratio916,
          cameraAspectRatio: CameraAspectRatios.ratio_16_9,
        );
      case ratio916:
        return const CameraAspectRatioChoice(
          label: ratio11,
          cameraAspectRatio: CameraAspectRatios.ratio_1_1,
        );
      case ratio11:
        return const CameraAspectRatioChoice(
          label: full,
          cameraAspectRatio: CameraAspectRatios.ratio_16_9,
        );
      default:
        return const CameraAspectRatioChoice(
          label: ratio34,
          cameraAspectRatio: CameraAspectRatios.ratio_4_3,
        );
    }
  }

  static CameraPreviewFit previewFit(String selectedAspectRatio) {
    if (selectedAspectRatio == full) {
      return CameraPreviewFit.cover;
    }
    return CameraPreviewFit.contain;
  }

  static Alignment previewAlignment(String selectedAspectRatio) {
    if (selectedAspectRatio == ratio34) {
      return Alignment.topCenter;
    }
    return Alignment.center;
  }
}
