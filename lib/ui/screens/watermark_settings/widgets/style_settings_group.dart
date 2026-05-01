import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    return Column(
      children: [
        SettingsSectionWrapper(
          title: 'Plantilla de Diseno',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SettingIconBubble(icon: CupertinoIcons.sparkles),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text(
                              'Estilo visual',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Elige la plantilla de la marca de agua',
                              style: TextStyle(
                                color: Color(0x73FFFFFF),
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: config.template,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    thumbColor: AppColors.settingsAccent,
                    children: const <String, Widget>{
                      WatermarkTemplateType.crystal: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: Text('Cristal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      WatermarkTemplateType.pill: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: Text('Pildora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      WatermarkTemplateType.cinema: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: Text('Cine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    },
                    onValueChanged: (String? value) {
                      if (value == null) return;
                      onConfigChanged(config.copyWith(template: value));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSectionWrapper(
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
        ),
      ],
    );
  }
}
