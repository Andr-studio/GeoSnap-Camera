import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geosnap_cam/data/repositories/watermark_settings_repository.dart';
import 'package:geosnap_cam/core/services/permission_service.dart';
import 'package:geosnap_cam/services/gps/gps_service.dart';
import 'package:geosnap_cam/services/watermark/map_tile_service.dart';
import 'package:geosnap_cam/services/watermark/watermark_service.dart';

final GetIt appLocator = GetIt.instance;

Future<void> configureDependencies() async {
  if (appLocator.isRegistered<SharedPreferences>()) return;

  appLocator.registerSingletonAsync<SharedPreferences>(
    SharedPreferences.getInstance,
  );

  appLocator.registerLazySingleton<http.Client>(
    http.Client.new,
    dispose: (client) => client.close(),
  );

  appLocator.registerLazySingleton<PermissionService>(
    () => PermissionService(prefs: appLocator<SharedPreferences>()),
  );

  appLocator.registerLazySingleton<GpsService>(
    () => GpsService(httpClient: appLocator<http.Client>()),
  );

  appLocator.registerLazySingleton<MapTileService>(
    () => MapTileService(httpClient: appLocator<http.Client>()),
  );

  appLocator.registerLazySingleton<WatermarkSettingsRepository>(
    () => WatermarkSettingsRepository(prefs: appLocator<SharedPreferences>()),
  );

  appLocator.registerLazySingleton<WatermarkService>(
    () => WatermarkService(
      settingsRepository: appLocator<WatermarkSettingsRepository>(),
      mapTileService: appLocator<MapTileService>(),
    ),
  );

  await appLocator.allReady();
}

Future<void> disposeDependencies() => appLocator.reset(dispose: true);
