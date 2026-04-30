import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'watermark_config.dart';

class MapTileService {
  static const int _mapZoom = 16;
  static const int _mapTileSize = 256;
  static const int _mapViewportSize = 512;

  final http.Client _httpClient;
  final Map<String, ui.Image> _mapCache = <String, ui.Image>{};

  MapTileService({required http.Client httpClient}) : _httpClient = httpClient;

  ui.Image? getCachedMapImage({
    required double latitude,
    required double longitude,
    required String mapType,
  }) {
    final _MapTileLocation tile = _latLonToTileLocation(
      latitude,
      longitude,
      _mapZoom,
    );
    return _mapCache[_cacheKey(mapType, tile, _mapZoom)];
  }

  Future<ui.Image?> getOrFetchMapImage({
    required double latitude,
    required double longitude,
    required String mapType,
  }) async {
    final _MapTileLocation tile = _latLonToTileLocation(
      latitude,
      longitude,
      _mapZoom,
    );
    final String key = _cacheKey(mapType, tile, _mapZoom);
    final ui.Image? cached = _mapCache[key];
    if (cached != null) return cached;

    try {
      final ui.Image? image = await _buildCenteredMapImage(
        mapType: mapType,
        center: tile,
      );
      if (image == null) return null;
      _mapCache[key] = image;

      if (_mapCache.length > 60) {
        _mapCache.remove(_mapCache.keys.first);
      }

      return image;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image?> _buildCenteredMapImage({
    required String mapType,
    required _MapTileLocation center,
  }) async {
    final double viewportHalf = _mapViewportSize / 2.0;
    final int firstTileX = ((center.worldPixelX - viewportHalf) / _mapTileSize)
        .floor();
    final int lastTileX = ((center.worldPixelX + viewportHalf) / _mapTileSize)
        .floor();
    final int firstTileY = ((center.worldPixelY - viewportHalf) / _mapTileSize)
        .floor();
    final int lastTileY = ((center.worldPixelY + viewportHalf) / _mapTileSize)
        .floor();
    final double originWorldX = center.worldPixelX - viewportHalf;
    final double originWorldY = center.worldPixelY - viewportHalf;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    bool drewAnyTile = false;

    for (int x = firstTileX; x <= lastTileX; x++) {
      for (int y = firstTileY; y <= lastTileY; y++) {
        if (y < 0 || y > center.maxTile) continue;

        final int wrappedX = _wrapTileX(x, center.maxTile + 1);
        final ui.Image? tileImage = await _fetchTileImage(
          mapType: mapType,
          x: wrappedX,
          y: y,
          z: _mapZoom,
        );
        if (tileImage == null) continue;

        final double dx = (x * _mapTileSize) - originWorldX;
        final double dy = (y * _mapTileSize) - originWorldY;
        final Rect dst = Rect.fromLTWH(
          dx,
          dy,
          _mapTileSize.toDouble(),
          _mapTileSize.toDouble(),
        );
        final Rect src = Rect.fromLTWH(
          0,
          0,
          tileImage.width.toDouble(),
          tileImage.height.toDouble(),
        );
        canvas.drawImageRect(tileImage, src, dst, Paint());
        drewAnyTile = true;
      }
    }

    final ui.Picture picture = recorder.endRecording();
    if (!drewAnyTile) return null;
    return picture.toImage(_mapViewportSize, _mapViewportSize);
  }

  Future<ui.Image?> _fetchTileImage({
    required String mapType,
    required int x,
    required int y,
    required int z,
  }) async {
    final Uri uri = _buildTileUri(mapType: mapType, x: x, y: y, z: z);
    final http.Response response = await _httpClient.get(uri);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return _decodeImage(response.bodyBytes);
  }

  static int _wrapTileX(int x, int tileCount) {
    return ((x % tileCount) + tileCount) % tileCount;
  }

  static String _cacheKey(String mapType, _MapTileLocation tile, int z) {
    return '$mapType:$z:${tile.worldPixelX.round()}:${tile.worldPixelY.round()}';
  }

  static Uri _buildTileUri({
    required String mapType,
    required int x,
    required int y,
    required int z,
  }) {
    switch (mapType) {
      case WatermarkMapType.satellite:
        return Uri.parse(
          'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x',
        );
      case WatermarkMapType.terrain:
        return Uri.parse('https://a.tile.opentopomap.org/$z/$x/$y.png');
      case WatermarkMapType.standard:
      default:
        return Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png');
    }
  }

  static _MapTileLocation _latLonToTileLocation(
    double lat,
    double lon,
    int zoom,
  ) {
    final double clampedLat = lat.clamp(-85.0511, 85.0511);
    final double n = math.pow(2.0, zoom).toDouble();
    final double worldSize = n * _mapTileSize;
    final double worldPixelX = ((lon + 180.0) / 360.0) * worldSize;
    final double latRad = clampedLat * math.pi / 180.0;
    final double worldPixelY =
        ((1.0 -
            math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) /
        2.0 *
        worldSize);

    final int maxTile = n.toInt() - 1;
    final double clampedWorldPixelX = worldPixelX.clamp(0.0, worldSize - 1);
    final double clampedWorldPixelY = worldPixelY.clamp(0.0, worldSize - 1);
    return _MapTileLocation(
      worldPixelX: clampedWorldPixelX,
      worldPixelY: clampedWorldPixelY,
      maxTile: maxTile,
    );
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}

class _MapTileLocation {
  final double worldPixelX;
  final double worldPixelY;
  final int maxTile;

  const _MapTileLocation({
    required this.worldPixelX,
    required this.worldPixelY,
    required this.maxTile,
  });
}
