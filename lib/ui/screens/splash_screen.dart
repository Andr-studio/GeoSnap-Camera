import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/permission_service.dart';
import 'permission_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget mainApp;

  const SplashScreen({super.key, required this.mainApp});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final PermissionService _permissionService = appLocator<PermissionService>();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final results = await Future.wait<bool>([
      _permissionService.isOnboardingComplete(),
      _permissionService.hasAllPermissions(),
    ]);
    final bool onboardingComplete = results[0];
    final bool hasPermissions = results[1];

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
      if (onboardingComplete && hasPermissions) {
        _navigateTo(widget.mainApp);
      } else {
        _navigateTo(PermissionScreen(grantedScreen: widget.mainApp));
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
        transitionDuration: const Duration(milliseconds: 180),
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
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isChecking
              ? const CupertinoActivityIndicator(
                  radius: 10,
                  color: Colors.white70,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
