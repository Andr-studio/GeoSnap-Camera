import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';

import 'settings_section_wrapper.dart';
import 'watermark_settings_theme.dart';

class MapSettingsGroup extends StatelessWidget {
  final WatermarkConfig config;
  final ValueChanged<WatermarkConfig> onConfigChanged;

  const MapSettingsGroup({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWrapper(
      title: 'Marca del mapa',
      children: <Widget>[
        SliderSettingTile(
          icon: CupertinoIcons.textformat_size,
          title: 'Tamano de Google',
          valueLabel: '${(config.mapAttributionScale * 100).round()}%',
          value: config.mapAttributionScale,
          min: 0.7,
          max: 2.2,
          divisions: 15,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(mapAttributionScale: value));
          },
        ),
        const SettingsDivider(),
        SliderSettingTile(
          icon: CupertinoIcons.circle,
          title: 'Contorno de Google',
          valueLabel:
              '${config.mapAttributionOutlineWidth.toStringAsFixed(1)} px',
          value: config.mapAttributionOutlineWidth,
          min: 0.0,
          max: 4.0,
          divisions: 16,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(mapAttributionOutlineWidth: value));
          },
        ),
        const SettingsDivider(),
        ColorPickerTile(
          icon: CupertinoIcons.paintbrush,
          title: 'Color de Google',
          selectedValue: config.mapAttributionColorValue,
          onSelected: (Color color) {
            onConfigChanged(
              config.copyWith(mapAttributionColorValue: color.toARGB32()),
            );
          },
          colors: const <Color>[
            Colors.white,
            Colors.black,
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
          ],
        ),
      ],
    );
  }
}
