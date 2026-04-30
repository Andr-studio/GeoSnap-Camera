import 'package:flutter/widgets.dart';

class CameraPhotoSizePolicy {
  static const double defaultMegapixels = 12.0;
  static const double highResMegapixelsThreshold = 40.0;

  static double toMegapixels(Size size) {
    return (size.width * size.height) / 1000000;
  }

  static String formatMegapixelsLabel(Size size) {
    return '${toMegapixels(size).round()}M';
  }

  static List<Size> buildSortedUniqueOptions(List<Size> sizes) {
    final Map<String, Size> uniqueByDimensions = <String, Size>{};
    for (final Size size in sizes) {
      if (size.width <= 0 || size.height <= 0) continue;
      final String key = '${size.width.round()}x${size.height.round()}';
      uniqueByDimensions[key] = size;
    }

    final List<Size> candidates = uniqueByDimensions.values.toList()
      ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));

    if (candidates.isEmpty) return <Size>[];

    final int baseIndex = findDefaultIndex(candidates);
    final Size baseSize = candidates[baseIndex];

    Size? highResSize;
    for (final Size size in candidates) {
      if (toMegapixels(size) >= highResMegapixelsThreshold) {
        highResSize = size;
      }
    }

    if (highResSize == null) {
      return <Size>[baseSize];
    }

    final bool sameSize =
        baseSize.width == highResSize.width &&
        baseSize.height == highResSize.height;
    if (sameSize) {
      return <Size>[baseSize];
    }

    return <Size>[baseSize, highResSize];
  }

  static int findDefaultIndex(List<Size> options) {
    if (options.isEmpty) return -1;
    int bestIndex = 0;
    double bestDiff = (toMegapixels(options[0]) - defaultMegapixels).abs();
    for (int i = 1; i < options.length; i++) {
      final double currentMp = toMegapixels(options[i]);
      final double bestMp = toMegapixels(options[bestIndex]);
      final double diff = (currentMp - defaultMegapixels).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
        continue;
      }
      if (diff == bestDiff &&
          currentMp <= defaultMegapixels &&
          bestMp > defaultMegapixels) {
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
