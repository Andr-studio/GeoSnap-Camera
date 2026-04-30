import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class VideoWatermarkProcessor {
  /// Codifica el video con la marca de agua superpuesta.
  /// Intenta primero `h264_mediacodec` y cae en `libx264` si falla.
  static Future<bool> encode({
    required String inputPath,
    required String watermarkPath,
    required String outputPath,
  }) async {
    const String filterComplex =
        "[1:v][0:v]scale2ref=w='main_w*min(iw,ih)/2280':h='main_h*min(iw,ih)/2280'[wm][vid];[vid][wm]overlay=(W-w)/2:H-h-(H*0.02)[out]";

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
