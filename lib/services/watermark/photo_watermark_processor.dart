import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:flutter/services.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
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
    final RootIsolateToken rootToken = RootIsolateToken.instance!;
    
    return Isolate.run(() async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
      final Stopwatch stopwatch = Stopwatch()..start();
      
      try {
        final File inputFile = File(inputPath);
        final Size rawSize = ImageSizeGetter.getSizeResult(FileInput(inputFile)).size;
        int logicalWidth = rawSize.width;
        int logicalHeight = rawSize.height;

        // Leer orientación de EXIF para saber si la imagen está rotada lógicamente
        final Exif tempExif = await Exif.fromPath(inputPath);
        final Map<String, Object>? attributes = await tempExif.getAttributes();
        await tempExif.close();

        if (attributes != null) {
          final String orientation = attributes['Orientation']?.toString() ?? '1';
          // 6 = Rotate 90 CW, 8 = Rotate 270 CW
          if (orientation == '6' || orientation == '8' || orientation.contains('90') || orientation.contains('270')) {
             logicalWidth = rawSize.height;
             logicalHeight = rawSize.width;
          }
        }
        
        final Uint8List watermarkBytes = await watermarkFile.readAsBytes();
        final Size watermarkSize = ImageSizeGetter.getSizeResult(MemoryInput(watermarkBytes)).size;

        final int targetWidth =
            (logicalWidth * _photoOverlayWidthFactor(config)).round();
        final int targetHeight =
            (targetWidth * watermarkSize.height / watermarkSize.width).round();
        final int safeWidth = targetWidth.clamp(1, logicalWidth);
        final int safeHeight = targetHeight.clamp(1, logicalHeight);
        
        final int x = ((logicalWidth - safeWidth) / 2).round();
        final int y =
            (logicalHeight - safeHeight - (logicalHeight * 0.02))
                .round()
                .clamp(0, logicalHeight - safeHeight);

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
        
        if (result == null || result.isEmpty) {
          debugPrint('Watermark Processor: ImageEditor returned null/empty in ${stopwatch.elapsedMilliseconds}ms');
          return null;
        }

        await File(outputPath).writeAsBytes(result, flush: true);
        await _writePhotoExif(
          sourcePath: inputPath,
          outputPath: outputPath,
          location: location,
        );
        
        stopwatch.stop();
        debugPrint('⏱️ Watermark Processor (Isolate) finalizado en: ${stopwatch.elapsedMilliseconds}ms');
        
        return outputPath;
      } catch (e) {
        debugPrint('Watermark Processor Error: $e');
        return null;
      }
    });
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
}

