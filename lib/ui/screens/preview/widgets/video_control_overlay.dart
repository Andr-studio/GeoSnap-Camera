import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class VideoControlOverlay extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;

  const VideoControlOverlay({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onTogglePlay,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final double total = duration.inMilliseconds.toDouble();
    final double progress = position.inMilliseconds.toDouble().clamp(
      0.0,
      total > 0 ? total : 1.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: onTogglePlay,
        child: Row(
          children: <Widget>[
            Icon(
              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            _DurationLabel(duration: position),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 2.5,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: progress,
                  min: 0,
                  max: total > 0 ? total : 1.0,
                  onChanged: (double value) {
                    onSeek(Duration(milliseconds: value.round()));
                  },
                ),
              ),
            ),
            _DurationLabel(duration: duration),
          ],
        ),
      ),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final Duration duration;

  const _DurationLabel({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(duration),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  String _format(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
