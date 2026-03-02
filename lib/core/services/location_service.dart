import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../../features/shipment/domain/models/shipment_model.dart';

/// Service responsible for background GPS location tracking.
///
/// Implements throttling logic:
/// - Updates every 8 seconds OR 40 meters movement
/// - High accuracy only during active trips
/// - Dead zone handling: stores points locally (Hive) and syncs when back online
class LocationService {
  final Logger _logger;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  bool _isTracking = false;

  /// Callback to handle new location points for syncing.
  Function(LocationPoint)? onLocationUpdate;

  LocationService({required Logger logger}) : _logger = logger;

  bool get isTracking => _isTracking;

  /// Check and request location permissions.
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Get the current position once.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      _logger.e('Get current position error: $e');
      return null;
    }
  }

  /// Start continuous location tracking with throttling.
  /// Uses high accuracy during active trips.
  void startTracking() {
    if (_isTracking) return;

    _isTracking = true;
    _lastUpdateTime = DateTime.now();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.locationDistanceFilterMeters.toInt(),
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _onPositionUpdate,
          onError: (error) {
            _logger.e('Location stream error: $error');
          },
        );

    _logger.i('Location tracking started');
  }

  /// Stop location tracking.
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _lastUpdateTime = null;
    _logger.i('Location tracking stopped');
  }

  /// Handle incoming position updates with throttling.
  void _onPositionUpdate(Position position) {
    final now = DateTime.now();

    // Throttle: skip if less than 8 seconds since last update
    if (_lastUpdateTime != null) {
      final elapsed = now.difference(_lastUpdateTime!).inMilliseconds;
      if (elapsed < AppConstants.locationUpdateIntervalMs) {
        return;
      }
    }

    // Also check distance filter as backup
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // If the driver hasn't moved enough AND hasn't been long enough, skip
      if (distance < AppConstants.locationDistanceFilterMeters &&
          _lastUpdateTime != null &&
          now.difference(_lastUpdateTime!).inMilliseconds <
              AppConstants.locationUpdateIntervalMs * 2) {
        return;
      }
    }

    _lastPosition = position;
    _lastUpdateTime = now;

    final point = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      accuracy: position.accuracy,
      heading: position.heading,
      timestamp: now,
    );

    _logger.d(
      'Location update: ${position.latitude}, ${position.longitude} '
      '(speed: ${position.speed.toStringAsFixed(1)} m/s)',
    );

    onLocationUpdate?.call(point);
  }

  /// Store a location point locally for dead zone handling.
  Future<void> cacheLocationPoint(LocationPoint point) async {
    try {
      final box = await Hive.openBox<Map>('cached_locations');
      await box.add(point.toJson());

      if (box.length > AppConstants.maxCachedLocationPoints) {
        // Remove oldest entries to prevent unbounded growth
        final keysToRemove = box.keys
            .take(box.length - AppConstants.maxCachedLocationPoints)
            .toList();
        await box.deleteAll(keysToRemove);
      }
    } catch (e) {
      _logger.e('Cache location point error: $e');
    }
  }

  /// Retrieve and clear cached location points for sync.
  Future<List<LocationPoint>> getCachedPoints() async {
    try {
      final box = await Hive.openBox<Map>('cached_locations');
      final points = box.values.map((map) {
        return LocationPoint.fromJson(Map<String, dynamic>.from(map));
      }).toList();

      await box.clear();
      _logger.i('Retrieved ${points.length} cached location points');
      return points;
    } catch (e) {
      _logger.e('Get cached points error: $e');
      return [];
    }
  }

  /// Dispose resources.
  void dispose() {
    stopTracking();
  }
}
