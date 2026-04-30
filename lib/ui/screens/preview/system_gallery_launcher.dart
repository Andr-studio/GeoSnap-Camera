import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

class SystemGalleryLauncher {
  static Future<void> open(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        final List<AndroidIntent> intents = <AndroidIntent>[
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.sec.android.gallery3d',
            flags: <int>[268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.APP_GALLERY',
            flags: <int>[268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.photos',
            flags: <int>[268435456],
          ),
          const AndroidIntent(
            action: 'android.intent.action.VIEW',
            type: 'image/*',
            flags: <int>[268435456],
          ),
          const AndroidIntent(action: 'android.provider.action.PICK_IMAGES'),
        ];
        for (final AndroidIntent intent in intents) {
          if (await _tryLaunchAndroidIntent(intent)) return;
        }
        throw Exception('No gallery intent resolved');
      }
      await Gal.open();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la galeria del sistema'),
        ),
      );
    }
  }

  static Future<bool> _tryLaunchAndroidIntent(AndroidIntent intent) async {
    try {
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }
}
