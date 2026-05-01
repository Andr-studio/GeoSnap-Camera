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
  }) async {
    final double widthFactor = config.effectiveGlassWidth.clamp(0.42, 0.76).toDouble();
    final double aspectMultiplier = watermarkHeight / watermarkWidth;
    final double heightFactor = widthFactor * aspectMultiplier;

    // Use main_w for both width and height to guarantee aspect ratio is preserved perfectly.
    // The division by 2 and multiplication by 2 ensures the output height is an even number,
    // which is required by h264_mediacodec to prevent encoding errors.
    final String filterComplex =
        "[1:v][0:v]scale2ref=w='trunc(main_w*$widthFactor/2)*2':h='trunc(main_w*$heightFactor/2)*2'[wm][vid];[vid][wm]overlay=(W-w)/2:H-h-(H*0.02)[out]";

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
