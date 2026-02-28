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
import '../providers/app_providers.dart';

/// GoRouter configuration with role-based routing and auth guards.
final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authNotifierProvider);
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthRoute =
          state.uri.path == '/login' || state.uri.path == '/register';

      // If authenticated, redirect from auth routes to role-based home
      if (currentUser != null && isAuthRoute) {
        return _getHomeRoute(currentUser.role);
      }

      // If not authenticated, redirect to login
      if (currentUser == null && !isAuthRoute) {
        return '/login';
      }

      return null;
    },
    routes: [
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
