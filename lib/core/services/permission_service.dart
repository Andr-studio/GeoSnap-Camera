import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _onboardingCompleteKey = 'onboarding_complete';

  /// Check if all mandatory permissions are granted.
  Future<bool> hasAllPermissions() async {
    final statuses = await Future.wait([
      Permission.camera.status,
      Permission.microphone.status,
      Permission.locationWhenInUse.status,
      Permission.photos.status,
      Permission.videos.status,
    ]);

    bool cameraGranted = statuses[0].isGranted;
    bool micGranted = statuses[1].isGranted;
    bool locationGranted = statuses[2].isGranted || statuses[2].isLimited;
    bool storageGranted = statuses[3].isGranted || statuses[3].isLimited || 
                         statuses[4].isGranted || statuses[4].isLimited;

    print('DEBUG - Permission Status:');
    print('Camera: $cameraGranted');
    print('Micro: $micGranted');
    print('Location: $locationGranted');
    print('Storage/Photos: $storageGranted');

    return cameraGranted && micGranted && locationGranted && storageGranted;
  }

  /// Request all mandatory permissions.
  Future<bool> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.locationWhenInUse,
      Permission.photos,
      Permission.videos,
    ].request();

    bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    bool micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    bool locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? 
                          statuses[Permission.locationWhenInUse]?.isLimited ?? false;
    
    bool storageGranted = (statuses[Permission.photos]?.isGranted ?? false) ||
                         (statuses[Permission.photos]?.isLimited ?? false) ||
                         (statuses[Permission.videos]?.isGranted ?? false) ||
                         (statuses[Permission.videos]?.isLimited ?? false);

    print('DEBUG - Request Results:');
    print('Camera: $cameraGranted');
    print('Micro: $micGranted');
    print('Location: $locationGranted');
    print('Storage/Photos: $storageGranted');

    return cameraGranted && micGranted && locationGranted && storageGranted;
  }

  /// Check if the user has already seen and accepted the initial permission screen.
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark the onboarding as complete.
  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }
}
