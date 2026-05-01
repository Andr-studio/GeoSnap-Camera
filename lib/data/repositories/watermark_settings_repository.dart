import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/watermark/watermark_config.dart';

class WatermarkSettingsRepository {
  final SharedPreferences _prefs;

  WatermarkSettingsRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final ValueNotifier<WatermarkConfig> configNotifier = ValueNotifier(
    WatermarkConfig(),
  );

  Future<WatermarkConfig> getConfig() async {
    final SharedPreferences prefs = _prefs;
    final String template = prefs.getString('wm_template') ?? WatermarkTemplateType.crystal;
    final String mapType =
        prefs.getString('wm_mapType') ?? WatermarkMapType.standard;
    final double titleScale = prefs.getDouble('wm_titleScale') ?? 0.55;
    final double textScale = prefs.getDouble('wm_textScale') ?? 0.65;
    final double glassOpacity = prefs.getDouble('wm_glassOpacity') ?? 0.55;
    final double glassWidth = prefs.getDouble('wm_glassWidth') ?? 1.0;
    final int titleColorValue =
        prefs.getInt('wm_titleColorValue') ?? 0xFFFFFFFF;
    final int textColorValue = prefs.getInt('wm_textColorValue') ?? 0xFFFFFFFF;
    final int glassColorValue =
        prefs.getInt('wm_glassColorValue') ?? 0xFF070707;
    final double mapAttributionScale =
        prefs.getDouble('wm_mapAttributionScale') ?? 1.0;
    final double mapAttributionOutlineWidth =
        prefs.getDouble('wm_mapAttributionOutlineWidth') ??
        ((prefs.getBool('wm_mapAttributionShadow') ?? true) ? 1.2 : 0.0);
    final int mapAttributionColorValue =
        prefs.getInt('wm_mapAttributionColorValue') ?? 0xFFFFFFFF;

    final WatermarkConfig config = WatermarkConfig(
      showDate: prefs.getBool('wm_showDate') ?? true,
      showAddress: prefs.getBool('wm_showAddress') ?? true,
      showCityCoords: prefs.getBool('wm_showCityCoords') ?? true,
      template: WatermarkTemplateType.values.contains(template)
          ? template
          : WatermarkTemplateType.crystal,
      mapType: WatermarkMapType.values.contains(mapType)
          ? mapType
          : WatermarkMapType.standard,
      titleScale: titleScale.clamp(0.4, 1.6).toDouble(),
      textScale: textScale.clamp(0.4, 1.6).toDouble(),
      glassOpacity: glassOpacity.clamp(0.0, 1.0).toDouble(),
      glassWidth: glassWidth.clamp(0.5, 1.0).toDouble(),
      titleColorValue: titleColorValue,
      textColorValue: textColorValue,
      glassColorValue: glassColorValue,
      mapAttributionScale: mapAttributionScale.clamp(0.7, 2.2).toDouble(),
      mapAttributionOutlineWidth: mapAttributionOutlineWidth
          .clamp(0.0, 4.0)
          .toDouble(),
      mapAttributionColorValue: mapAttributionColorValue,
    );

    configNotifier.value = config;
    return config;
  }

  Future<void> saveConfig(WatermarkConfig config) async {
    await Future.wait([
      _prefs.setBool('wm_showDate', config.showDate),
      _prefs.setBool('wm_showAddress', config.showAddress),
      _prefs.setBool('wm_showCityCoords', config.showCityCoords),
      _prefs.setString('wm_template', config.template),
      _prefs.setString('wm_mapType', config.mapType),
      _prefs.setDouble('wm_titleScale', config.titleScale),
      _prefs.setDouble('wm_textScale', config.textScale),
      _prefs.setDouble('wm_glassOpacity', config.glassOpacity),
      _prefs.setDouble('wm_glassWidth', config.glassWidth),
      _prefs.setInt('wm_titleColorValue', config.titleColorValue),
      _prefs.setInt('wm_textColorValue', config.textColorValue),
      _prefs.setInt('wm_glassColorValue', config.glassColorValue),
      _prefs.setDouble('wm_mapAttributionScale', config.mapAttributionScale),
      _prefs.setDouble(
        'wm_mapAttributionOutlineWidth',
        config.mapAttributionOutlineWidth,
      ),
      _prefs.setInt(
        'wm_mapAttributionColorValue',
        config.mapAttributionColorValue,
      ),
    ]);
    configNotifier.value = config;
  }
}
