import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set status bar to transparent for a more premium look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoSnap Cam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', // Defaulting to Roboto as defined in pubspec
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D1D1F),
          primary: const Color(0xFF1D1D1F),
          surface: const Color(0xFFF8F9FA),
        ),
      ),
      home: const SplashScreen(
        mainApp: CameraScreen(),
      ),
    );
  }
}

