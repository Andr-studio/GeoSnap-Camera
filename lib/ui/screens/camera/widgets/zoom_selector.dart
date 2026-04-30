import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zoom_selector_views.dart';

class ZoomSelector extends StatefulWidget {
  final SensorConfig sensorConfig;
  final ValueNotifier<int> pinchExpandNotifier;
  final bool compactMode;
  final double iconRotationTurns;

  const ZoomSelector({
    super.key,
    required this.sensorConfig,
    required this.pinchExpandNotifier,
    this.compactMode = false,
    this.iconRotationTurns = 0.0,
  });

  @override
  State<ZoomSelector> createState() => ZoomSelectorState();
}

class ZoomSelectorState extends State<ZoomSelector> {
  bool _isExpanded = false;
  Timer? _collapseTimer;
  StreamSubscription<double>? _zoomSubscription;
  double _currentZoom = 0.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _isBoundsReady = false;
  double _lastHapticValue = -1.0;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.sensorConfig.zoom;
    _lastHapticValue = _currentZoom;
    _zoomSubscription = widget.sensorConfig.zoom$.listen(_onZoomChanged);
    widget.pinchExpandNotifier.addListener(_onPinchExpandRequested);
    _loadZoomBounds();
  }

  @override
  void didUpdateWidget(covariant ZoomSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorConfig != widget.sensorConfig) {
      _zoomSubscription?.cancel();
      _currentZoom = widget.sensorConfig.zoom;
      _zoomSubscription = widget.sensorConfig.zoom$.listen(_onZoomChanged);
      _loadZoomBounds();
    }
    if (oldWidget.pinchExpandNotifier != widget.pinchExpandNotifier) {
      oldWidget.pinchExpandNotifier.removeListener(_onPinchExpandRequested);
      widget.pinchExpandNotifier.addListener(_onPinchExpandRequested);
    }
  }

  @override
  void dispose() {
    widget.pinchExpandNotifier.removeListener(_onPinchExpandRequested);
    _zoomSubscription?.cancel();
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _onZoomChanged(double zoom) {
    if (!mounted) return;

    if ((zoom - _lastHapticValue).abs() > 0.05) {
      HapticFeedback.selectionClick();
      _lastHapticValue = zoom;
    }

    setState(() {
      _currentZoom = zoom;
    });
  }

  void _onPinchExpandRequested() {
    if (!mounted) return;
    setState(_expandAndResetTimer);
  }

  Future<void> _loadZoomBounds() async {
    try {
      final double minZoom = await CamerawesomePlugin.getMinZoom() ?? 1.0;
      final double maxZoom = await CamerawesomePlugin.getMaxZoom() ?? 1.0;
      if (!mounted) return;
      setState(() {
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _isBoundsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _isBoundsReady = true;
      });
    }
  }

  void _expandAndResetTimer() {
    _isExpanded = true;
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  void _setZoom(double value) {
    widget.sensorConfig.setZoom(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
        ),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return ZoomCollapsedView(
      displayStops: _displayStops(expanded: false),
      labelForStop: _stopLabel,
      normalizedZoomForStop: _toNormalizedZoom,
      isStopSelected: _isStopSelected,
      iconRotationTurns: widget.iconRotationTurns,
      onZoomSelected: _setZoom,
    );
  }

  Widget _buildExpandedView() {
    return ZoomExpandedView(
      compact: widget.compactMode,
      currentZoom: _currentZoom,
      zoomLabel: _zoomLabel(_currentZoom),
      displayStops: _displayStops(expanded: true),
      labelForStop: _stopLabel,
      normalizedZoomForStop: _toNormalizedZoom,
      isStopSelected: _isStopSelected,
      iconRotationTurns: widget.iconRotationTurns,
      onZoomSelected: _setZoom,
    );
  }

  String _zoomLabel(double value) {
    final double displayZoom = _toDisplayZoom(value);
    return '${displayZoom.toStringAsFixed(displayZoom >= 10 ? 0 : 1)}x';
  }

  double _toDisplayZoom(double normalizedZoom) {
    if (!_isBoundsReady) {
      return normalizedZoom;
    }
    return (_maxZoom - _minZoom) * normalizedZoom + _minZoom;
  }

  double _toNormalizedZoom(double displayZoom) {
    if (!_isBoundsReady || (_maxZoom - _minZoom).abs() < 0.0001) {
      return 0.0;
    }
    return ((displayZoom - _minZoom) / (_maxZoom - _minZoom)).clamp(0.0, 1.0);
  }

  List<double> _displayStops({required bool expanded}) {
    if (!_isBoundsReady) {
      return <double>[1.0];
    }
    final List<double> candidates = expanded
        ? <double>[_minZoom, 1.0, 2.0, 3.0, 5.0, 10.0, _maxZoom]
        : <double>[_minZoom, 1.0, 2.0, _maxZoom];
    final List<double> filtered = <double>[];

    for (final double value in candidates) {
      if (value < _minZoom || value > _maxZoom) continue;
      final bool alreadyAdded = filtered.any(
        (double existing) => (existing - value).abs() < 0.05,
      );
      if (!alreadyAdded) {
        filtered.add(value);
      }
    }

    if (filtered.isEmpty) {
      return <double>[_minZoom];
    }
    return filtered;
  }

  String _stopLabel(double displayZoom) {
    return displayZoom >= 10
        ? displayZoom.toStringAsFixed(0)
        : displayZoom.toStringAsFixed(1).replaceAll('.0', '');
  }

  bool _isStopSelected(double displayZoom) {
    final double currentDisplayZoom = _toDisplayZoom(_currentZoom);
    return (currentDisplayZoom - displayZoom).abs() <= 0.15;
  }
}
