import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/services/gps_service.dart';
import 'package:geosnap_cam/services/watermark_service.dart';

class WatermarkSettingsScreen extends StatefulWidget {
  final LocationData? currentLocation;

  const WatermarkSettingsScreen({
    super.key,
    this.currentLocation,
  });

  @override
  State<WatermarkSettingsScreen> createState() => _WatermarkSettingsScreenState();
}

class _WatermarkSettingsScreenState extends State<WatermarkSettingsScreen> {
  WatermarkConfig _config = WatermarkConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final WatermarkConfig config = await WatermarkService.getConfig();
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
    await WatermarkService.saveConfig(newConfig);
    await _prewarmAssets(newConfig);
  }

  Future<void> _prewarmAssets(WatermarkConfig config) async {
    await WatermarkService.prewarmWatermarkAssets(_effectiveLocation, config);
    if (mounted) {
      setState(() {});
    }
  }

  LocationData get _effectiveLocation {
    return widget.currentLocation ??
        LocationData(
          latitude: -23.604062,
          longitude: -70.377349,
          address: 'Pasaje Cabo - Crispin Reyes 7159',
          city: 'Antofagasta',
          region: 'Antofagasta',
          country: 'Chile',
          countryCode: 'CL',
          postalCode: '1265859',
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

    final DateTime now = DateTime.now();
    final LocationData previewLocation = _effectiveLocation;
    final Size wmSize = WatermarkPainter.measureSize(
      location: previewLocation,
      config: _config,
      date: now,
    );
    final uiImage = WatermarkService.getCachedMapImage(previewLocation, _config);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Marca de agua GPS'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                bottom: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISTA PREVIA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 380,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1542314831-c6a420325142?auto=format&fit=crop&w=900&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.bottomCenter,
                              child: CustomPaint(
                                size: wmSize,
                                painter: WatermarkPainter(
                                  location: previewLocation,
                                  config: _config,
                                  date: now,
                                  mapImage: uiImage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'La vista previa se renderiza igual que en fotos y videos',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSegmentedMapType(),
                const SizedBox(height: 12),
                _buildTextScaleSlider(),
                const SizedBox(height: 12),
                _buildGlassOpacitySlider(),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Mostrar fecha y hora',
                  icon: CupertinoIcons.calendar,
                  value: _config.showDate,
                  onChanged: (v) => _updateConfig(_config.copyWith(showDate: v)),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Mostrar dirección + código postal',
                  icon: CupertinoIcons.map_pin_ellipse,
                  value: _config.showAddress,
                  onChanged: (v) => _updateConfig(_config.copyWith(showAddress: v)),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  title: 'Mostrar latitud y longitud',
                  icon: CupertinoIcons.location_solid,
                  value: _config.showCityCoords,
                  onChanged: (v) => _updateConfig(_config.copyWith(showCityCoords: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedMapType() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vista del mapa',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: _config.mapType,
            backgroundColor: Colors.black26,
            thumbColor: const Color(0xFFFFD700),
            children: const <String, Widget>{
              WatermarkMapType.standard: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text('Estándar'),
              ),
              WatermarkMapType.satellite: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text('Satélite'),
              ),
              WatermarkMapType.terrain: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text('Relieve'),
              ),
            },
            onValueChanged: (String? value) {
              if (value == null) return;
              _updateConfig(_config.copyWith(mapType: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextScaleSlider() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tamaño de texto (${_config.textScale.toStringAsFixed(2)}x)',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _config.textScale,
            min: 0.4,
            max: 1.6,
            divisions: 24,
            activeColor: const Color(0xFFFFD700),
            inactiveColor: Colors.white24,
            onChanged: (double value) {
              _updateConfig(_config.copyWith(textScale: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassOpacitySlider() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opacidad del cristal (${(_config.glassOpacity * 100).toInt()}%)',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _config.glassOpacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: const Color(0xFFFFD700),
            inactiveColor: Colors.white24,
            onChanged: (double value) {
              _updateConfig(_config.copyWith(glassOpacity: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        secondary: Icon(icon, color: Colors.white70),
        value: value,
        activeColor: const Color(0xFFFFD700),
        onChanged: onChanged,
      ),
    );
  }
}
