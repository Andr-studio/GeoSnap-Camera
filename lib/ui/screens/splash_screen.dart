import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/services/permission_service.dart';
import 'permission_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget mainApp;

  const SplashScreen({super.key, required this.mainApp});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final PermissionService _permissionService = PermissionService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    // Artificial delay for splash aesthetic
    await Future.delayed(const Duration(seconds: 3));

    final bool onboardingComplete = await _permissionService.isOnboardingComplete();
    final bool hasPermissions = await _permissionService.hasAllPermissions();

    if (mounted) {
      if (onboardingComplete && hasPermissions) {
        _navigateTo(widget.mainApp);
      } else {
        _navigateTo(PermissionScreen(
          onGranted: () => _navigateTo(widget.mainApp),
        ));
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder for a high-end logo/icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1F),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.camera_viewfinder,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'GeoSnap Cam',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 48),
              const CupertinoActivityIndicator(radius: 12),
            ],
          ),
        ),
      ),
    );
  }
}
