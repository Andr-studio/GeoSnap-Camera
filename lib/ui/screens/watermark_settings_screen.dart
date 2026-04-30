import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/core/di/service_locator.dart';
import 'package:geosnap_cam/services/gps/gps_service.dart';
import 'package:geosnap_cam/data/repositories/watermark_settings_repository.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings/widgets/content_settings_group.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings/widgets/map_settings_group.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings/widgets/settings_preview_card.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings/widgets/style_settings_group.dart';
import 'package:geosnap_cam/ui/screens/watermark_settings/widgets/watermark_settings_theme.dart';

class WatermarkSettingsScreen extends StatefulWidget {
  final LocationData? currentLocation;

  const WatermarkSettingsScreen({super.key, this.currentLocation});

  @override
  State<WatermarkSettingsScreen> createState() =>
      _WatermarkSettingsScreenState();
}

class _WatermarkSettingsScreenState extends State<WatermarkSettingsScreen> {
  final WatermarkService _watermarkService = appLocator<WatermarkService>();
  final WatermarkSettingsRepository _settingsRepo =
      appLocator<WatermarkSettingsRepository>();
  WatermarkConfig _config = WatermarkConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final WatermarkConfig config = await _settingsRepo.getConfig();
    if (!mounted) return;

    setState(() {
      _config = config;
      _isLoading = false;
    });

    await _prewarmAssets(config);
  }

  Future<void> _updateConfig(WatermarkConfig newConfig) async {
    setState(() {
      _config = newConfig;
    });
    await _settingsRepo.saveConfig(newConfig);
    await _prewarmAssets(newConfig);
  }

  Future<void> _prewarmAssets(WatermarkConfig config) async {
    await _watermarkService.prewarmWatermarkAssets(_effectiveLocation, config);
    if (mounted) {
      setState(() {});
    }
  }

  LocationData get _effectiveLocation {
    return widget.currentLocation ??
        LocationData(
          latitude: -23.604062,
          longitude: -70.377349,
          address: 'Pasaje Ejemplo 1234',
          city: 'Ejemplopolis',
          region: 'Ejemploregion',
          country: 'Ejemplopais',
          countryCode: 'CL',
          postalCode: '1234567',
          timezone: 'America/Santiago',
          temperatureC: 17.9,
          windKmh: 9.1,
          uvIndex: 0.0,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    final LocationData previewLocation = _effectiveLocation;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Marca de agua GPS'),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.black,
              AppColors.settingsSurface,
              Color(0xFF06090B),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 32,
          ),
          children: <Widget>[
            SettingsPreviewCard(
              config: _config,
              location: previewLocation,
              mapImage: _watermarkService.getCachedMapImage(
                previewLocation,
                _config,
              ),
            ),
            const SizedBox(height: 16),
            StyleSettingsGroup(config: _config, onConfigChanged: _updateConfig),
            const SizedBox(height: 14),
            MapSettingsGroup(config: _config, onConfigChanged: _updateConfig),
            const SizedBox(height: 14),
            ContentSettingsGroup(
              config: _config,
              onConfigChanged: _updateConfig,
            ),
          ],
        ),
      ),
    );
  }
}
