import 'package:flutter/cupertino.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';

import 'settings_section_wrapper.dart';
import 'watermark_settings_theme.dart';

class StyleSettingsGroup extends StatelessWidget {
  final WatermarkConfig config;
  final ValueChanged<WatermarkConfig> onConfigChanged;

  const StyleSettingsGroup({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWrapper(
      title: 'Apariencia',
      children: <Widget>[
        SliderSettingTile(
          icon: CupertinoIcons.textformat_size,
          title: 'Tamano del titulo',
          valueLabel: '${(config.titleScale * 100).round()}%',
          value: config.titleScale,
          min: 0.4,
          max: 1.6,
          divisions: 24,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(titleScale: value));
          },
        ),
        const SettingsDivider(),
        SliderSettingTile(
          icon: CupertinoIcons.textformat_size,
          title: 'Tamano del texto',
          valueLabel: '${(config.textScale * 100).round()}%',
          value: config.textScale,
          min: 0.4,
          max: 1.6,
          divisions: 24,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(textScale: value));
          },
        ),
        const SettingsDivider(),
        SliderSettingTile(
          icon: CupertinoIcons.rectangle_expand_vertical,
          title: 'Ancho maximo',
          valueLabel: '${(config.glassWidth * 100).round()}%',
          value: config.glassWidth,
          min: 0.5,
          max: 1.0,
          divisions: 10,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(glassWidth: value));
          },
        ),
        const SettingsDivider(),
        SliderSettingTile(
          icon: CupertinoIcons.drop,
          title: 'Cristal de agua',
          valueLabel: '${(config.glassOpacity * 100).round()}%',
          value: config.glassOpacity,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (double value) {
            onConfigChanged(config.copyWith(glassOpacity: value));
          },
        ),
        const SettingsDivider(),
        ColorPickerTile(
          icon: CupertinoIcons.drop,
          title: 'Color del cristal',
          selectedValue: config.glassColorValue,
          onSelected: (Color color) {
            onConfigChanged(config.copyWith(glassColorValue: color.toARGB32()));
          },
          colors: const <Color>[
            Color(0xFF123A55),
            Color(0xFF2A6F97),
            Color.fromARGB(255, 7, 7, 7),
            Color(0xFF4C3F91),
            Color(0xFF255D42),
            Color(0xFF5C4635),
          ],
        ),
        const SettingsDivider(),
        ColorPickerTile(
          icon: CupertinoIcons.paintbrush,
          title: 'Color del titulo',
          selectedValue: config.titleColorValue,
          onSelected: (Color color) {
            onConfigChanged(config.copyWith(titleColorValue: color.toARGB32()));
          },
        ),
        const SettingsDivider(),
        ColorPickerTile(
          icon: CupertinoIcons.textformat,
          title: 'Color del texto',
          selectedValue: config.textColorValue,
          onSelected: (Color color) {
            onConfigChanged(config.copyWith(textColorValue: color.toARGB32()));
          },
        ),
      ],
    );
  }
}
