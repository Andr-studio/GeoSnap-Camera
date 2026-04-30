class WatermarkMapType {
  static const String standard = 'standard';
  static const String satellite = 'satellite';
  static const String terrain = 'terrain';

  static const List<String> values = <String>[standard, satellite, terrain];
}

class WatermarkConfig {
  static const double widthScaleFactor = 0.85;

  final bool showDate;
  final bool showAddress;
  final bool showCityCoords;
  final String mapType;
  final double titleScale;
  final double textScale;
  final double glassOpacity;
  final double glassWidth;
  final int titleColorValue;
  final int textColorValue;
  final int glassColorValue;
  final double mapAttributionScale;
  final double mapAttributionOutlineWidth;
  final int mapAttributionColorValue;

  WatermarkConfig({
    this.showDate = true,
    this.showAddress = true,
    this.showCityCoords = true,
    this.mapType = WatermarkMapType.standard,
    this.titleScale = 0.55,
    this.textScale = 0.65,
    this.glassOpacity = 0.55,
    this.glassWidth = 1.0,
    this.titleColorValue = 0xFFFFFFFF,
    this.textColorValue = 0xFFFFFFFF,
    this.glassColorValue = 0xFF070707,
    this.mapAttributionScale = 1.0,
    this.mapAttributionOutlineWidth = 1.2,
    this.mapAttributionColorValue = 0xFFFFFFFF,
  });

  double get effectiveGlassWidth => glassWidth * widthScaleFactor;

  WatermarkConfig copyWith({
    bool? showDate,
    bool? showAddress,
    bool? showCityCoords,
    String? mapType,
    double? titleScale,
    double? textScale,
    double? glassOpacity,
    double? glassWidth,
    int? titleColorValue,
    int? textColorValue,
    int? glassColorValue,
    double? mapAttributionScale,
    double? mapAttributionOutlineWidth,
    int? mapAttributionColorValue,
  }) {
    return WatermarkConfig(
      showDate: showDate ?? this.showDate,
      showAddress: showAddress ?? this.showAddress,
      showCityCoords: showCityCoords ?? this.showCityCoords,
      mapType: mapType ?? this.mapType,
      titleScale: titleScale ?? this.titleScale,
      textScale: textScale ?? this.textScale,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassWidth: glassWidth ?? this.glassWidth,
      titleColorValue: titleColorValue ?? this.titleColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      glassColorValue: glassColorValue ?? this.glassColorValue,
      mapAttributionScale: mapAttributionScale ?? this.mapAttributionScale,
      mapAttributionOutlineWidth:
          mapAttributionOutlineWidth ?? this.mapAttributionOutlineWidth,
      mapAttributionColorValue:
          mapAttributionColorValue ?? this.mapAttributionColorValue,
    );
  }
}
