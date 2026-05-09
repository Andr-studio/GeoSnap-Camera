import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'; // Para FileImage y evict()
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

class _WatermarkTask {
  final String sourcePath;
  final MediaCapture mediaCapture;
  final LocationData location;

  _WatermarkTask({
    required this.sourcePath,
    required this.mediaCapture,
    required this.location,
  });
}

class CameraMediaStore {
  static const String _galleryAlbumName = 'GeoSnap';
  static const Set<String> _photoExts = {'.jpg', '.jpeg', '.png', '.heic'};
  static const Set<String> _videoExts = {'.mp4', '.mov', '.mkv'};
  static const int _maxSessionFiles = 30;

  final WatermarkService _watermarkService;
  bool _galleryAccessChecked = false;
  bool _galleryAccessGranted = false;

  // Cola de tareas para dispositivos de gama baja
  final Queue<_WatermarkTask> _taskQueue = Queue<_WatermarkTask>();
  bool _isProcessingQueue = false;

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

    // 1. Copia instantánea de la foto cruda a la ruta permanente
    try {
      await File(rawPath).copy(permanentPath);
    } catch (e) {
      debugPrint('Error copying raw file: $e');
      return null;
    }

    // 2. Procesamiento en segundo plano en cola (para no saturar el dispositivo)
    if (location != null) {
      _taskQueue.add(
        _WatermarkTask(
          sourcePath: permanentPath,
          mediaCapture: mediaCapture,
          location: location,
        ),
      );
      _processNextInQueue();
    } else {
      _saveToSystemGallery(mediaCapture, permanentPath);
    }

    // 3. ¡Liberamos el obturador instantáneamente!
    return SavedCameraMedia(path: permanentPath, isVideo: mediaCapture.isVideo);
  }

  Future<void> _processNextInQueue() async {
    if (_isProcessingQueue || _taskQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_taskQueue.isNotEmpty) {
      final _WatermarkTask task = _taskQueue.removeFirst();
      await _processWatermarkBackground(
        sourcePath: task.sourcePath,
        mediaCapture: task.mediaCapture,
        location: task.location,
      );
      // Breve pausa para dejar respirar a la UI en dispositivos de gama baja
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    _isProcessingQueue = false;
  }

  Future<void> _processWatermarkBackground({
    required String sourcePath,
    required MediaCapture mediaCapture,
    required LocationData location,
  }) async {
    final String tempProcessedPath = '${sourcePath}_processed';
    
    final result = await _watermarkService.applyWatermark(
      sourcePath,
      mediaCapture.isVideo,
      location,
      outputPath: tempProcessedPath,
    );
    
    await result.fold(
      (failure) async {
        debugPrint('Background watermark failed: ${failure.message}');
        await _saveToSystemGallery(mediaCapture, sourcePath);
      },
      (processedPath) async {
        try {
          final File processedFile = File(processedPath);
          if (await processedFile.exists()) {
            await processedFile.copy(sourcePath);
            await processedFile.delete();
            // Evict the image from memory cache so the UI reloads it
            await FileImage(File(sourcePath)).evict();
          }
          await _saveToSystemGallery(mediaCapture, sourcePath);
        } catch (e) {
          debugPrint('Error finalizing background watermark: $e');
        }
      },
    );
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
