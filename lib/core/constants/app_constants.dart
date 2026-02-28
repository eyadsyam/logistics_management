/// Application-wide constants used throughout the Logistics Management system.
library;

class AppConstants {
  AppConstants._();

  // ── App Info ──
  static const String appName = 'Edita Logistics';
  static const String appVersion = '1.0.0';

  // ── Location Tracking Configuration ──
  /// Minimum time interval between GPS updates (milliseconds)
  static const int locationUpdateIntervalMs = 8000; // 8 seconds
  /// Minimum distance change to trigger update (meters)
  static const double locationDistanceFilterMeters = 40.0;

  /// Accuracy mode for active trips
  static const String highAccuracyMode = 'high';

  /// Accuracy mode for idle state
  static const String balancedAccuracyMode = 'balanced';

  // ── Firestore Collections ──
  static const String usersCollection = 'users';
  static const String driversCollection = 'drivers';
  static const String shipmentsCollection = 'shipments';
  static const String locationHistorySubcollection = 'location_history';

  // ── Shipment Statuses ──
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // ── User Roles ──
  static const String roleClient = 'client';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';

  // ── Mapbox ──
  static const String mapboxBaseUrl = 'https://api.mapbox.com';
  static const String mapboxDirectionsEndpoint =
      '/directions/v5/mapbox/driving';
  static const String mapboxOptimizationEndpoint =
      '/optimized-trips/v1/mapbox/driving';
  static const String mapboxStyleUrl = 'mapbox://styles/mapbox/light-v11';

  // ── Offline Sync ──
  /// Maximum number of cached location points before forced sync
  static const int maxCachedLocationPoints = 500;

  /// Sync retry interval in milliseconds
  static const int syncRetryIntervalMs = 30000; // 30 seconds

  // ── UI ──
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double mapDefaultZoom = 14.0;
  static const double mapTrackingZoom = 16.0;
}
