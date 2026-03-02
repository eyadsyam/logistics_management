import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/constants/app_colors.dart';

/// Provider that tracks whether the splash initialization is complete.
/// GoRouter's redirect reads this to know when to navigate away from splash.
final splashCompleteProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _animController.forward();

    // Fire-and-forget async initialization — no ref/context after any await
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // ── Cache ref properties BEFORE any async gap! ──
    // This is the absolute root cause of FlutterError (Widget unmounted).
    final locService = ref.read(locationServiceProvider);

    // ── 1. Branding time ──
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // ── 2. Location permissions (best-effort, don't crash) ──
    try {
      await locService.checkPermissions();
    } catch (_) {}
    if (!mounted) return;

    // ── 3. Warm up GPS (best-effort) ──
    try {
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {}
    if (!mounted) return;

    // ── 4. Signal completion — GoRouter redirect will navigate ──
    ref.read(splashCompleteProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the splash provider — when it becomes true, GoRouter
    // redirect fires and navigates to the correct home/login screen.
    ref.watch(splashCompleteProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/app_icon.png',
                      width: 140,
                      height: 140,
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Initializing...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
