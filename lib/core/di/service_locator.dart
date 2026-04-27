import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geosnap_cam/core/services/permission_service.dart';
import 'package:geosnap_cam/services/gps_service.dart';
import 'package:geosnap_cam/services/watermark_service.dart';

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

  appLocator.registerLazySingleton<WatermarkService>(
    () => WatermarkService(
      prefs: appLocator<SharedPreferences>(),
      httpClient: appLocator<http.Client>(),
    ),
  );

  await appLocator.allReady();
}

Future<void> disposeDependencies() => appLocator.reset(dispose: true);
