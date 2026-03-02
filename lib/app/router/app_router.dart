import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/client/presentation/screens/client_home_screen.dart';
import '../../features/client/presentation/screens/shipment_tracking_screen.dart';
import '../../features/driver/presentation/screens/driver_home_screen.dart';
import '../../features/driver/presentation/screens/driver_trip_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../providers/app_providers.dart';

/// Notifier that triggers a GoRouter redirect when authentication or splash state changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Listen to dependencies and trigger GoRouter when they change
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
    _ref.listen(currentUserProvider, (_, __) => notifyListeners());
    _ref.listen(splashCompleteProvider, (_, __) => notifyListeners());
  }
}

/// GoRouter configuration with role-based routing and auth guards.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    refreshListenable: notifier, // Automatically triggers the redirect
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isSplash = state.uri.path == '/splash';
      final isAuthRoute =
          state.uri.path == '/login' || state.uri.path == '/register';

      // Read current state correctly
      final currentUser = ref.read(currentUserProvider);
      final splashDone = ref.read(splashCompleteProvider);

      // ── Stay on splash until initialization completes ──
      if (isSplash) {
        if (!splashDone) return null; // Keep showing splash
        // Splash done — navigate to correct screen
        if (currentUser != null) {
          return _getHomeRoute(currentUser.role);
        }
        return '/login';
      }

      // If authenticated and trying to hit auth routes, redirect to home
      if (currentUser != null && isAuthRoute) {
        return _getHomeRoute(currentUser.role);
      }

      // If not authenticated and not on splash or auth routes, force login
      if (currentUser == null && !isAuthRoute) {
        return '/login';
      }

      return null;
    },
    routes: [
      // ── Splash Route ──
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth Routes ──
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Client Routes ──
      GoRoute(
        path: '/client',
        name: 'client-home',
        builder: (context, state) => const ClientHomeScreen(),
        routes: [
          GoRoute(
            path: 'tracking/:shipmentId',
            name: 'shipment-tracking',
            builder: (context, state) => ShipmentTrackingScreen(
              shipmentId: state.pathParameters['shipmentId']!,
            ),
          ),
        ],
      ),

      // ── Driver Routes ──
      GoRoute(
        path: '/driver',
        name: 'driver-home',
        builder: (context, state) => const DriverHomeScreen(),
        routes: [
          GoRoute(
            path: 'trip/:shipmentId',
            name: 'driver-trip',
            builder: (context, state) {
              final driverId = ref.read(currentUserProvider)?.id ?? '';
              return DriverTripScreen(
                shipmentId: state.pathParameters['shipmentId']!,
                driverId: driverId,
              );
            },
          ),
        ],
      ),

      // ── Admin Routes ──
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // ── Profile Route (shared) ──
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    ),
  );
});

/// Returns the home route based on user role.
String _getHomeRoute(String role) {
  switch (role) {
    case AppConstants.roleClient:
      return '/client';
    case AppConstants.roleDriver:
      return '/driver';
    case AppConstants.roleAdmin:
      return '/admin';
    default:
      return '/login';
  }
}
