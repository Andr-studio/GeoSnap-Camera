import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';

import 'settings_section_wrapper.dart';
import 'watermark_settings_theme.dart';

class ContentSettingsGroup extends StatelessWidget {
  final WatermarkConfig config;
  final ValueChanged<WatermarkConfig> onConfigChanged;

  const ContentSettingsGroup({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWrapper(
      title: 'Contenido',
      children: <Widget>[
        SettingTile(
          icon: CupertinoIcons.map,
          title: 'Vista del mapa',
          subtitle: 'Elige el estilo del mapa dentro de la marca',
          trailing: CupertinoSlidingSegmentedControl<String>(
            groupValue: config.mapType,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: AppColors.settingsAccent,
            children: const <String, Widget>{
              WatermarkMapType.standard: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text('Mapa'),
              ),
              WatermarkMapType.satellite: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text('Sat'),
              ),
              WatermarkMapType.terrain: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text('Rel'),
              ),
            },
            onValueChanged: (String? value) {
              if (value == null) return;
              onConfigChanged(config.copyWith(mapType: value));
            },
          ),
        ),
        const SettingsDivider(),
        _ToggleTile(
          title: 'Mostrar fecha y hora',
          icon: CupertinoIcons.calendar,
          value: config.showDate,
          onChanged: (bool value) {
            onConfigChanged(config.copyWith(showDate: value));
          },
        ),
        const SettingsDivider(),
        _ToggleTile(
          title: 'Mostrar direccion y codigo postal',
          icon: CupertinoIcons.map_pin_ellipse,
          value: config.showAddress,
          onChanged: (bool value) {
            onConfigChanged(config.copyWith(showAddress: value));
          },
        ),
        const SettingsDivider(),
        _ToggleTile(
          title: 'Mostrar latitud y longitud',
          icon: CupertinoIcons.location_solid,
          value: config.showCityCoords,
          onChanged: (bool value) {
            onConfigChanged(config.copyWith(showCityCoords: value));
          },
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      icon: icon,
      title: title,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.settingsAccent,
        onChanged: onChanged,
      ),
    );
  }
}
