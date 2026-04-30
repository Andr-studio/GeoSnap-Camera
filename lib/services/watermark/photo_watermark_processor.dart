import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_editor/image_editor.dart';
import 'package:intl/intl.dart';
import 'package:native_exif/native_exif.dart';

import '../gps/gps_service.dart';
import 'watermark_config.dart';

class PhotoWatermarkProcessor {
  static Future<String?> apply({
    required String inputPath,
    required String outputPath,
    required File watermarkFile,
    required WatermarkConfig config,
    required LocationData location,
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
      final int y =
          (photoImage.height - safeHeight - (photoImage.height * 0.02))
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
      await _writePhotoExif(
        sourcePath: inputPath,
        outputPath: outputPath,
        location: location,
      );
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  static double _photoOverlayWidthFactor(WatermarkConfig config) {
    return config.effectiveGlassWidth.clamp(0.42, 0.76).toDouble();
  }

  static Future<void> _writePhotoExif({
    required String sourcePath,
    required String outputPath,
    required LocationData location,
  }) async {
    Exif? sourceExif;
    Exif? outputExif;
    try {
      sourceExif = await Exif.fromPath(sourcePath);
      outputExif = await Exif.fromPath(outputPath);

      final Map<String, Object> values = <String, Object>{};
      final Map<String, Object>? sourceAttributes = await sourceExif
          .getAttributes();
      if (sourceAttributes != null) {
        for (final MapEntry<String, Object> entry in sourceAttributes.entries) {
          final Object value = entry.value;
          if (value is String) {
            values[entry.key] = value;
          }
        }
      }

      final DateFormat exifDateFormat = DateFormat('yyyy:MM:dd HH:mm:ss');
      values['DateTimeOriginal'] =
          values['DateTimeOriginal'] ?? exifDateFormat.format(DateTime.now());
      values['DateTimeDigitized'] =
          values['DateTimeDigitized'] ?? values['DateTimeOriginal']!;
      values['Orientation'] = '1';
      values['GPSLatitude'] = location.latitude;
      values['GPSLongitude'] = location.longitude;
      values['GPSLatitudeRef'] = location.latitude < 0 ? 'S' : 'N';
      values['GPSLongitudeRef'] = location.longitude < 0 ? 'W' : 'E';
      values['GPSProcessingMethod'] = 'GPS';

      await outputExif.writeAttributes(values);
    } catch (_) {
      // Ignore EXIF errors to avoid failing the photo save flow.
    } finally {
      await sourceExif?.close();
      await outputExif?.close();
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
