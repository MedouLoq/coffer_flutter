import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/secure_storage_service.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthOnce();
  }

  Future<void> _checkAuthOnce() async {
    if (_navigated) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _navigated) return;

    try {
      final isLogged = await SecureStorageService.isLoggedIn();
      if (!mounted || _navigated) return;

      final hasVaultKey = await SecureStorageService.hasVaultKey();
      if (!mounted || _navigated) return;

      if (hasVaultKey && isLogged) {
        // Vault existe + connecté → déverrouillage
        _safeNavigate('/unlock_vault');
      } else if (isLogged) {
        // Connecté mais pas de vault → créer vault
        // ✅ CORRECTION : Passer userId et email
        final userId = await SecureStorageService.getUserId();
        final email = await SecureStorageService.getUserEmail();

        if (userId == null || email == null) {
          // Pas d'infos utilisateur → recommencer
          await SecureStorageService.clearAll();
          _safeNavigate('/login');
          return;
        }

        _safeNavigate('/setup_password', arguments: {
          'userId': userId,
          'email': email,
        });
      } else {
        // Pas connecté → login
        _safeNavigate('/login');
      }
    } catch (e) {
      debugPrint('❌ Erreur splash: $e');
      if (!mounted || _navigated) return;
      _safeNavigate('/login');
    }
  }

  void _safeNavigate(String route, {dynamic arguments}) {
    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.currentRoute == route) return;
      Get.offAllNamed(route, arguments: arguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[900]!, Colors.blue[700]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          size: 60,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Vault Secure',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chiffrement de bout en bout',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Chargement...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}