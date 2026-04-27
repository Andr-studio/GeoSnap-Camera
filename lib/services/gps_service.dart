import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String region;
  final String country;
  final String countryCode;
  final String postalCode;
  final String timezone;
  final double? temperatureC;
  final double? windKmh;
  final double? uvIndex;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    this.region = '',
    this.country = '',
    this.countryCode = '',
    this.postalCode = '',
    this.timezone = '',
    this.temperatureC,
    this.windKmh,
    this.uvIndex,
  });

  String get title {
    final List<String> parts = <String>[
      if (region.trim().isNotEmpty) region.trim(),
      if (city.trim().isNotEmpty) city.trim(),
      if (country.trim().isNotEmpty) country.trim(),
    ];
    return parts.join(', ');
  }

  String get addressWithPostal {
    final List<String> parts = <String>[
      if (address.trim().isNotEmpty) address.trim(),
      if (postalCode.trim().isNotEmpty) postalCode.trim(),
    ];
    return parts.join(', ');
  }
}

class GpsService {
  final http.Client _httpClient;

  GpsService({required http.Client httpClient}) : _httpClient = httpClient;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      // Reducir accuracy a medium para obtener posición instantánea desde
      // red/WiFi. High espera señal satelital (3-8 s extra).
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );

      // Paralelizar geocoding y weather: antes era secuencial (1-3 s extra).
      final results = await Future.wait([
        _resolveAddress(position.latitude, position.longitude),
        _fetchWeatherSnapshot(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      ]);

      final _AddressResult addr = results[0] as _AddressResult;
      final _WeatherSnapshot weather = results[1] as _WeatherSnapshot;

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addr.address,
        city: addr.city,
        region: addr.region,
        country: addr.country,
        countryCode: addr.countryCode,
        postalCode: addr.postalCode,
        timezone: weather.timezone,
        temperatureC: weather.temperatureC,
        windKmh: weather.windKmh,
        uvIndex: weather.uvIndex,
      );
    } catch (e) {
      return null;
    }
  }

  Future<_AddressResult> _resolveAddress(double lat, double lon) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return const _AddressResult();

      final Placemark place = placemarks.first;
      final List<String> addressParts = <String>[
        if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
        if ((place.subLocality ?? '').trim().isNotEmpty)
          place.subLocality!.trim(),
      ];
      final List<String> cityParts = <String>[
        if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
        if ((place.subAdministrativeArea ?? '').trim().isNotEmpty)
          place.subAdministrativeArea!.trim(),
      ];
      String address = addressParts.join(', ');
      String city = cityParts.join(', ');
      final String region = (place.administrativeArea ?? '').trim();

      if (address.isEmpty) {
        final List<String> fallback = <String>[
          if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
          if ((place.thoroughfare ?? '').trim().isNotEmpty)
            place.thoroughfare!.trim(),
        ];
        address = fallback.join(', ');
      }
      if (city.isEmpty) city = region;

      return _AddressResult(
        address: address,
        city: city,
        region: region,
        country: (place.country ?? '').trim(),
        countryCode: (place.isoCountryCode ?? '').trim(),
        postalCode: (place.postalCode ?? '').trim(),
      );
    } catch (_) {
      return const _AddressResult();
    }
  }

  Future<_WeatherSnapshot> _fetchWeatherSnapshot({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final Uri uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,wind_speed_10m,uv_index'
        '&timezone=auto',
      );
      final http.Response response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        return const _WeatherSnapshot();
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _WeatherSnapshot();
      }

      final Map<String, dynamic> current =
          decoded['current'] is Map<String, dynamic>
          ? decoded['current'] as Map<String, dynamic>
          : <String, dynamic>{};

      return _WeatherSnapshot(
        timezone: (decoded['timezone'] ?? '').toString(),
        temperatureC: _toDoubleOrNull(current['temperature_2m']),
        windKmh: _toDoubleOrNull(current['wind_speed_10m']),
        uvIndex: _toDoubleOrNull(current['uv_index']),
      );
    } catch (_) {
      return const _WeatherSnapshot();
    }
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _AddressResult {
  final String address;
  final String city;
  final String region;
  final String country;
  final String countryCode;
  final String postalCode;

  const _AddressResult({
    this.address = '',
    this.city = '',
    this.region = '',
    this.country = '',
    this.countryCode = '',
    this.postalCode = '',
  });
}

class _WeatherSnapshot {
  final String timezone;
  final double? temperatureC;
  final double? windKmh;
  final double? uvIndex;

  const _WeatherSnapshot({
    this.timezone = '',
    this.temperatureC,
    this.windKmh,
    this.uvIndex,
  });
}
