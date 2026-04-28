import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/permission_service.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback? onGranted;
  final Widget? grantedScreen;

  const PermissionScreen({super.key, this.onGranted, this.grantedScreen});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionService _permissionService = appLocator<PermissionService>();
  bool _isRequesting = false;

  Future<void> _handlePermissions() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      final granted = await _permissionService.requestAllPermissions();

      if (granted) {
        await _permissionService.setOnboardingComplete();
        if (mounted) {
          setState(() => _isRequesting = false);
          final Widget? grantedScreen = widget.grantedScreen;
          if (grantedScreen != null) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    grantedScreen,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 180),
              ),
            );
          } else {
            widget.onGranted?.call();
          }
        }
      } else {
        if (mounted) {
          setState(() => _isRequesting = false);
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Permisos Requeridos'),
              content: const Text(
                'GeoSnap Cam necesita estos permisos para funcionar correctamente. Por favor, acéptalos en la configuración.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Entendido'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Ceramic White base
      body: Stack(
        children: [
          // Background accents (subtle soft gradients)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    'GeoSnap Cam',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: Color(0xFF1D1D1F), // Apple Dark Gray
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Captura tus momentos con precisión. Para empezar, necesitamos algunos permisos.',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFF86868B), // Apple Light Gray
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Permission Cards
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        _PermissionCard(
                          icon: CupertinoIcons.camera_fill,
                          title: 'Cámara',
                          description:
                              'Para capturar fotos y videos impresionantes.',
                        ),
                        _PermissionCard(
                          icon: CupertinoIcons.mic_fill,
                          title: 'Micrófono',
                          description: 'Para grabar el audio de tus videos.',
                        ),
                        _PermissionCard(
                          icon: CupertinoIcons.location_fill,
                          title: 'Ubicación Precisa',
                          description:
                              'Para geolocalizar tus capturas automáticamente.',
                        ),
                        _PermissionCard(
                          icon: CupertinoIcons.photo_fill,
                          title: 'Galería',
                          description:
                              'Para guardar y gestionar tus creaciones.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Premium Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: _PremiumButton(
                      text: 'Empezar ahora',
                      onPressed: _handlePermissions,
                      loading: _isRequesting,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFF007AFF), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF86868B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;

  const _PremiumButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D1D1F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: loading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
