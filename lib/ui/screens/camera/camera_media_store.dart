import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/gps/gps_service.dart';
import '../../../services/watermark/watermark_service.dart';

class CameraSessionMedia {
  final List<String> paths;
  final List<bool> isVideos;

  const CameraSessionMedia({required this.paths, required this.isVideos});
}

class SavedCameraMedia {
  final String path;
  final bool isVideo;

  const SavedCameraMedia({required this.path, required this.isVideo});
}

class CameraMediaStore {
  static const String _galleryAlbumName = 'GeoSnap';
  static const Set<String> _photoExts = {'.jpg', '.jpeg', '.png', '.heic'};
  static const Set<String> _videoExts = {'.mp4', '.mov', '.mkv'};
  static const int _maxSessionFiles = 30;

  final WatermarkService _watermarkService;
  bool _galleryAccessChecked = false;
  bool _galleryAccessGranted = false;

  CameraMediaStore({required WatermarkService watermarkService})
    : _watermarkService = watermarkService;

  Future<String> rawCapturePath(String extension) async {
    final Directory extDir = await getTemporaryDirectory();
    final Directory tempDir = await Directory(
      p.join(extDir.path, 'GeoSnap_raw'),
    ).create(recursive: true);
    return p.join(
      tempDir.path,
      '${DateTime.now().millisecondsSinceEpoch}$extension',
    );
  }

  Future<CameraSessionMedia> loadRecentSession() async {
    final Directory dir = await _geoSnapDir();
    if (!dir.existsSync()) {
      return const CameraSessionMedia(paths: <String>[], isVideos: <bool>[]);
    }

    final List<FileSystemEntity> entities = dir.listSync(followLinks: false)
      ..sort((a, b) {
        final int aMs = (a is File)
            ? a.lastModifiedSync().millisecondsSinceEpoch
            : 0;
        final int bMs = (b is File)
            ? b.lastModifiedSync().millisecondsSinceEpoch
            : 0;
        return bMs.compareTo(aMs);
      });

    final List<String> paths = <String>[];
    final List<bool> isVideos = <bool>[];

    for (final FileSystemEntity entity in entities) {
      if (entity is! File) continue;
      final String ext = p.extension(entity.path).toLowerCase();
      if (!_photoExts.contains(ext) && !_videoExts.contains(ext)) continue;
      paths.add(entity.path);
      isVideos.add(_videoExts.contains(ext));
      if (paths.length >= _maxSessionFiles) break;
    }

    return CameraSessionMedia(
      paths: paths.reversed.toList(),
      isVideos: isVideos.reversed.toList(),
    );
  }

  Future<SavedCameraMedia?> saveCapture({
    required MediaCapture mediaCapture,
    required LocationData? location,
  }) async {
    if (mediaCapture.status != MediaCaptureStatus.success) return null;
    final String? rawPath = mediaCapture.captureRequest.path;
    if (rawPath == null || rawPath.isEmpty) return null;
    if (!await File(rawPath).exists()) return null;
    if (!await _ensureGalleryAccess()) return null;

    final String extension = p.extension(rawPath);
    final String permanentPath = await _permanentOutputPath(extension);
    String finalPath = rawPath;

    if (location != null) {
      final result = await _watermarkService.applyWatermark(
        rawPath,
        mediaCapture.isVideo,
        location,
        outputPath: permanentPath,
      );
      finalPath = result.fold(
        (failure) {
          debugPrint('Watermark failed: ${failure.message}');
          return rawPath; // fallback to original file
        },
        (path) => path,
      );
    } else {
      try {
        await File(rawPath).copy(permanentPath);
        finalPath = permanentPath;
      } catch (_) {
        finalPath = rawPath;
      }
    }

    await _saveToSystemGallery(mediaCapture, finalPath);
    return SavedCameraMedia(path: finalPath, isVideo: mediaCapture.isVideo);
  }

  Future<Directory> _geoSnapDir() async {
    final Directory base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'GeoSnap')).create(recursive: true);
  }

  Future<String> _permanentOutputPath(String extension) async {
    final Directory dir = await _geoSnapDir();
    final String ts = DateTime.now().millisecondsSinceEpoch.toString();
    return p.join(dir.path, 'geosnap_$ts$extension');
  }

  Future<bool> _ensureGalleryAccess() async {
    if (_galleryAccessChecked) return _galleryAccessGranted;
    _galleryAccessChecked = true;
    try {
      final bool hasAccess = await Gal.hasAccess();
      if (hasAccess) {
        _galleryAccessGranted = true;
        return true;
      }
      _galleryAccessGranted = await Gal.requestAccess();
      return _galleryAccessGranted;
    } catch (_) {
      _galleryAccessGranted = false;
      return false;
    }
  }

  Future<void> _saveToSystemGallery(
    MediaCapture mediaCapture,
    String finalPath,
  ) async {
    try {
      if (mediaCapture.isPicture) {
        await Gal.putImage(finalPath, album: _galleryAlbumName);
      } else if (mediaCapture.isVideo) {
        await Gal.putVideo(finalPath, album: _galleryAlbumName);
      }
    } catch (_) {
      // Keep capture flow resilient if gallery save fails on specific devices.
    }
  }
}
