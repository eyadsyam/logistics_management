import 'dart:async';

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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Global error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[EDITA] FlutterError: ${details.exception}');
  };

  runApp(const ProviderScope(child: EditaFleetApp()));
}

/// Root application widget.
class EditaFleetApp extends ConsumerWidget {
  const EditaFleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watch auth to trigger rebuilds on auth state changes
    ref.watch(authNotifierProvider);

    // Handle auth state changes for navigation
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        authenticated: (user) {
          ref.read(currentUserProvider.notifier).state = user;
          // Navigate to role-based home
          switch (user.role) {
            case AppConstants.roleClient:
              router.go('/client');
              break;
            case AppConstants.roleDriver:
              router.go('/driver');
              break;
            case AppConstants.roleAdmin:
              router.go('/admin');
              break;
          }
        },
        unauthenticated: () {
          ref.read(currentUserProvider.notifier).state = null;
          router.go('/login');
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
