import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/providers/app_providers.dart';
import 'app/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/state/auth_state.dart';

/// Application entry point.
/// Initializes Firebase, Hive, Mapbox, and environment variables.
/// Wraps everything in global error handlers so no crash goes unhandled.
Future<void> main() async {
  // ── Zone-level guard: catches ALL uncaught async exceptions ──
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Flutter framework errors (widget tree, rendering, etc.) ──
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[EDITA ERROR] FlutterError: ${details.exception}');
        debugPrint('[EDITA ERROR] Stack: ${details.stack}');
        // Don't call FlutterError.presentError in release — just log it
      };

      // ── Platform-level errors (native plugin crashes, etc.) ──
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('[EDITA ERROR] PlatformError: $error');
        debugPrint('[EDITA ERROR] Stack: $stack');
        return true; // Handled — don't terminate the app
      };

      // Load environment variables
      await dotenv.load(fileName: '.env');

      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize Hive for local caching (dead zone handling)
      await Hive.initFlutter();

      // Set Mapbox access token
      final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
      MapboxOptions.setAccessToken(mapboxToken);

      // System UI configuration for light theme
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      runApp(const ProviderScope(child: EditaFleetApp()));
    },
    (error, stackTrace) {
      // ── Catches any uncaught async errors in the entire app ──
      debugPrint('[EDITA ERROR] Uncaught: $error');
      debugPrint('[EDITA ERROR] Stack: $stackTrace');
    },
  );
}

/// Root application widget.
class EditaFleetApp extends ConsumerWidget {
  const EditaFleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watch auth to trigger rebuilds on auth state changes
    ref.watch(authNotifierProvider);

    // Handle auth state changes — only update user state.
    // Navigation is handled by GoRouter redirect, NOT here.
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        authenticated: (user) {
          ref.read(currentUserProvider.notifier).state = user;
        },
        unauthenticated: () {
          ref.read(currentUserProvider.notifier).state = null;
        },
      );
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
