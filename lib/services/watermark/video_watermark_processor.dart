import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../services/watermark/watermark_config.dart';

class VideoWatermarkProcessor {
  /// Codifica el video con la marca de agua superpuesta.
  /// Intenta primero `h264_mediacodec` y cae en `libx264` si falla.
  static Future<bool> encode({
    required String inputPath,
    required String watermarkPath,
    required String outputPath,
    required WatermarkConfig config,
    required double watermarkWidth,
    required double watermarkHeight,
    required int videoWidth,
    required int videoHeight,
  }) async {
    final double widthFactor = config.effectiveGlassWidth.clamp(0.42, 0.76).toDouble();
    
    // Al usar el minimo entre ancho y alto, garantizamos que en videos 9:16 (verticales) 
    // la marca de agua tome exactamente el 76% del ancho (ej. 1080). Si el video tiene 
    // metadatos de rotacion corruptos y FFmpeg cree que es 1920x1080, el minimo seguira 
    // siendo 1080, evitando que la marca de agua se dimensione a 1459px y cubra toda la pantalla.
    final int safeBaseWidth = math.min(videoWidth, videoHeight);
    int targetWmWidth = (safeBaseWidth * widthFactor).round();
    int targetWmHeight = (targetWmWidth * (watermarkHeight / watermarkWidth)).round();
    
    // Forzar numeros pares para evitar errores en h264_mediacodec
    if (targetWmWidth % 2 != 0) targetWmWidth -= 1;
    if (targetWmHeight % 2 != 0) targetWmHeight -= 1;

    final String filterComplex =
        "[1:v]scale=$targetWmWidth:$targetWmHeight[wm];"
        "[0:v][wm]overlay=(main_w-overlay_w)/2:main_h-overlay_h-(main_h*0.02),"
        "crop='trunc(iw/16)*16':'trunc(ih/16)*16',"
        "format=yuv420p[out]";

    final String hwCommand =
        '-y -i "$inputPath" -i "$watermarkPath" '
        '-filter_complex "$filterComplex" '
        '-map "[out]" -map 0:a? '
        '-c:v h264_mediacodec -b:v 8M -c:a copy "$outputPath"';

    final hwSession = await FFmpegKit.execute(hwCommand);
    final hwCode = await hwSession.getReturnCode();
    if (ReturnCode.isSuccess(hwCode)) return true;

    final String swCommand =
        '-y -i "$inputPath" -i "$watermarkPath" '
        '-filter_complex "$filterComplex" '
        '-map "[out]" -map 0:a? '
        '-c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

    final swSession = await FFmpegKit.execute(swCommand);
    final swCode = await swSession.getReturnCode();
    return ReturnCode.isSuccess(swCode);
  }
}
