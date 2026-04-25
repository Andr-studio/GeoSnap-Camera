import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geosnap_cam/services/gps_service.dart';
import 'package:geosnap_cam/services/watermark_service.dart';

class WatermarkSettingsScreen extends StatefulWidget {
  final LocationData? currentLocation;

  const WatermarkSettingsScreen({super.key, this.currentLocation});

  @override
  State<WatermarkSettingsScreen> createState() =>
      _WatermarkSettingsScreenState();
}

class _WatermarkSettingsScreenState extends State<WatermarkSettingsScreen> {
  static const Color _accent = Color(0xFFFFD34D);
  static const Color _surface = Color(0xFF101113);
  static const Color _card = Color(0x9925292F);

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
            colors: <Color>[Colors.black, _surface, Color(0xFF06090B)],
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
            _buildPreviewSection(),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Apariencia',
              children: <Widget>[
                _buildTitleScaleSlider(),
                _buildDivider(),
                _buildTextScaleSlider(),
                _buildDivider(),
                _buildGlassWidthSlider(),
                _buildDivider(),
                _buildGlassOpacitySlider(),
                _buildDivider(),
                _buildGlassColorPicker(),
                _buildDivider(),
                _buildTitleColorPicker(),
                _buildDivider(),
                _buildTextColorPicker(),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Marca del mapa',
              children: <Widget>[
                _buildMapAttributionScaleSlider(),
                _buildDivider(),
                _buildMapAttributionOutlineSlider(),
                _buildDivider(),
                _buildMapAttributionColorPicker(),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Contenido',
              children: <Widget>[
                _buildSegmentedMapType(),
                _buildDivider(),
                _buildToggle(
                  title: 'Mostrar fecha y hora',
                  icon: CupertinoIcons.calendar,
                  value: _config.showDate,
                  onChanged: (v) =>
                      _updateConfig(_config.copyWith(showDate: v)),
                ),
                _buildDivider(),
                _buildToggle(
                  title: 'Mostrar dirección y código postal',
                  icon: CupertinoIcons.map_pin_ellipse,
                  value: _config.showAddress,
                  onChanged: (v) =>
                      _updateConfig(_config.copyWith(showAddress: v)),
                ),
                _buildDivider(),
                _buildToggle(
                  title: 'Mostrar latitud y longitud',
                  icon: CupertinoIcons.location_solid,
                  value: _config.showCityCoords,
                  onChanged: (v) =>
                      _updateConfig(_config.copyWith(showCityCoords: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final DateTime now = DateTime.now();
    final LocationData previewLocation = _effectiveLocation;
    final double canvasWidth =
        WatermarkService.canvasWidth * _config.effectiveGlassWidth;
    final Size wmSize = WatermarkPainter.measureSize(
      location: previewLocation,
      config: _config,
      date: now,
      canvasWidth: canvasWidth,
    );
    final mapImage = WatermarkService.getCachedMapImage(
      previewLocation,
      _config,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'VISTA PREVIA',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth - 32;
            final double scale = math.min(1.0, availableWidth / wmSize.width);
            final double previewWidth = wmSize.width * scale;
            final double previewHeight = wmSize.height * scale;

            return _GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF121A20), Color(0xFF050708)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: CustomPaint(
                            size: wmSize,
                            painter: WatermarkPainter(
                              location: previewLocation,
                              config: _config,
                              date: now,
                              mapImage: mapImage,
                              canvasWidth: canvasWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'La vista previa se adapta al tamaño real de la marca.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSegmentedMapType() {
    return _SettingTile(
      icon: CupertinoIcons.map,
      title: 'Vista del mapa',
      subtitle: 'Elige el estilo del mapa dentro de la marca',
      trailing: CupertinoSlidingSegmentedControl<String>(
        groupValue: _config.mapType,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        thumbColor: _accent,
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
          _updateConfig(_config.copyWith(mapType: value));
        },
      ),
    );
  }

  Widget _buildTextScaleSlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.textformat_size,
      title: 'Tamaño del texto',
      valueLabel: '${(_config.textScale * 100).round()}%',
      value: _config.textScale,
      min: 0.4,
      max: 1.6,
      divisions: 24,
      onChanged: (double value) {
        _updateConfig(_config.copyWith(textScale: value));
      },
    );
  }

  Widget _buildTitleScaleSlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.textformat_size,
      title: 'Tamano del titulo',
      valueLabel: '${(_config.titleScale * 100).round()}%',
      value: _config.titleScale,
      min: 0.4,
      max: 1.6,
      divisions: 24,
      onChanged: (double value) {
        _updateConfig(_config.copyWith(titleScale: value));
      },
    );
  }

  Widget _buildGlassWidthSlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.rectangle_expand_vertical,
      title: 'Ancho máximo',
      valueLabel: '${(_config.glassWidth * 100).round()}%',
      value: _config.glassWidth,
      min: 0.5,
      max: 1.0,
      divisions: 10,
      onChanged: (double value) {
        _updateConfig(_config.copyWith(glassWidth: value));
      },
    );
  }

  Widget _buildGlassOpacitySlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.drop,
      title: 'Cristal de agua',
      valueLabel: '${(_config.glassOpacity * 100).round()}%',
      value: _config.glassOpacity,
      min: 0.0,
      max: 1.0,
      divisions: 20,
      onChanged: (double value) {
        _updateConfig(_config.copyWith(glassOpacity: value));
      },
    );
  }

  Widget _buildMapAttributionScaleSlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.textformat_size,
      title: 'Tamano de Google',
      valueLabel: '${(_config.mapAttributionScale * 100).round()}%',
      value: _config.mapAttributionScale,
      min: 0.7,
      max: 2.2,
      divisions: 15,
      onChanged: (double value) {
        _updateConfig(_config.copyWith(mapAttributionScale: value));
      },
    );
  }

  Widget _buildMapAttributionOutlineSlider() {
    return _buildSliderTile(
      icon: CupertinoIcons.circle,
      title: 'Contorno de Google',
      valueLabel: '${_config.mapAttributionOutlineWidth.toStringAsFixed(1)} px',
      value: _config.mapAttributionOutlineWidth,
      min: 0.0,
      max: 4.0,
      divisions: 16,
      onChanged: (double value) {
        _updateConfig(
          _config.copyWith(mapAttributionOutlineWidth: value),
        );
      },
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              thumbColor: _accent,
              overlayColor: _accent.withValues(alpha: 0.16),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextColorPicker() {
    return _buildColorPicker(
      icon: CupertinoIcons.textformat,
      title: 'Color del texto',
      selectedValue: _config.textColorValue,
      onSelected: (Color color) {
        _updateConfig(_config.copyWith(textColorValue: color.toARGB32()));
      },
    );
  }

  Widget _buildTitleColorPicker() {
    return _buildColorPicker(
      icon: CupertinoIcons.paintbrush,
      title: 'Color del titulo',
      selectedValue: _config.titleColorValue,
      onSelected: (Color color) {
        _updateConfig(_config.copyWith(titleColorValue: color.toARGB32()));
      },
    );
  }

  Widget _buildGlassColorPicker() {
    return _buildColorPicker(
      icon: CupertinoIcons.drop,
      title: 'Color del cristal',
      selectedValue: _config.glassColorValue,
      onSelected: (Color color) {
        _updateConfig(_config.copyWith(glassColorValue: color.toARGB32()));
      },
      colors: const <Color>[
        Color(0xFF123A55),
        Color(0xFF2A6F97),
        Color(0xFF345B63),
        Color(0xFF4C3F91),
        Color(0xFF255D42),
        Color(0xFF5C4635),
      ],
    );
  }

  Widget _buildMapAttributionColorPicker() {
    return _buildColorPicker(
      icon: CupertinoIcons.paintbrush,
      title: 'Color de Google',
      selectedValue: _config.mapAttributionColorValue,
      onSelected: (Color color) {
        _updateConfig(
          _config.copyWith(mapAttributionColorValue: color.toARGB32()),
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
    );
  }

  Widget _buildColorPicker({
    required IconData icon,
    required String title,
    required int selectedValue,
    required ValueChanged<Color> onSelected,
    List<Color> colors = const <Color>[
      Colors.white,
      Color(0xFFFFF1B6),
      Color(0xFFBFEAFF),
      Color(0xFFC9F7D4),
      Color(0xFFFFC6D6),
      Color(0xFFFFD34D),
    ],
  }) {
    final Color selectedColor = Color(selectedValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((Color color) {
              final bool selected = color == selectedColor;
              return GestureDetector(
                onTap: () {
                  onSelected(color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _accent : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.24),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
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
    return _SettingTile(
      icon: icon,
      title: title,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: _accent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: _WatermarkSettingsScreenState._card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          _IconBubble(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0x73FFFFFF),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;

  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 19),
    );
  }
}
