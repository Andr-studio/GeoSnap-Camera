import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geosnap_cam/ui/theme/app_colors.dart';

class ShutterButton extends StatefulWidget {
  final bool isVideoMode;
  final bool isRecording;
  final VoidCallback onTap;

  const ShutterButton({
    super.key,
    required this.isVideoMode,
    this.isRecording = false,
    required this.onTap,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;
  bool _pulse = false;

  @override
  void didUpdateWidget(covariant ShutterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVideoMode != widget.isVideoMode ||
        oldWidget.isRecording != widget.isRecording) {
      _pressed = false;
      _pulse = false;
    }
  }

  Future<void> _triggerPulse() async {
    setState(() {
      _pulse = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _pulse = false;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _pressed = true;
    });
    if (!widget.isVideoMode) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() {
      _pressed = false;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() {
      _pressed = false;
    });
  }

  void _handleTap() {
    if (widget.isVideoMode) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      _triggerPulse();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool videoVisual = widget.isVideoMode || widget.isRecording;

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: _pressed ? 0.78 : 1.0),
              width: videoVisual ? 3 : 5,
            ),
            boxShadow: <BoxShadow>[
              if (videoVisual)
                BoxShadow(
                  color: Colors.red.withValues(
                    alpha: widget.isRecording ? 0.36 : 0.18,
                  ),
                  blurRadius: widget.isRecording ? 22 : 14,
                  spreadRadius: widget.isRecording ? 2 : 0,
                )
              else
                BoxShadow(
                  color: Colors.white.withValues(alpha: _pulse ? 0.34 : 0.10),
                  blurRadius: _pulse ? 26 : 12,
                  spreadRadius: _pulse ? 3 : 0,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: widget.isRecording ? 34 : null,
                height: widget.isRecording ? 34 : null,
                decoration: BoxDecoration(
                  color: videoVisual ? AppColors.recordingRed : Colors.white,
                  borderRadius: BorderRadius.circular(
                    widget.isRecording ? 8 : 40,
                  ),
                ),
                margin: EdgeInsets.all(widget.isRecording ? 0 : 0),
              ),
              if (!videoVisual)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pulse ? 1 : 0,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.10),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              if (videoVisual && !widget.isRecording)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _pressed ? 18 : 22,
                  height: _pressed ? 18 : 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
