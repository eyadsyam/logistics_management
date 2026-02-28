import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_constants.dart';

/// Service for Mapbox API interactions.
///
/// Handles:
/// - Directions API for route calculation
/// - Geocoding for address lookup
/// - Optimization API for vehicle routing (stretch goal)
///
/// Note: The secret Mapbox token for server-side operations is stored
/// in Firebase Functions environment config, NOT in the app.
class MapboxService {
  final Dio _dio;
  final Logger _logger;

  late final String _accessToken;

  MapboxService({required Dio dio, required Logger logger})
    : _dio = dio,
      _logger = logger {
    _accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';

    if (_accessToken.isEmpty) {
      _logger.e('MAPBOX_ACCESS_TOKEN not found in .env');
    }
  }

  /// Get driving directions between two points.
  /// Returns route geometry (polyline), distance, and duration.
  Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final url =
          '${AppConstants.mapboxBaseUrl}${AppConstants.mapboxDirectionsEndpoint}'
          '/$originLng,$originLat;$destLng,$destLat';

      final response = await _dio.get(
        url,
        queryParameters: {
          'access_token': _accessToken,
          'geometries': 'polyline6',
          'overview': 'full',
          'steps': 'false',
          'alternatives': 'false',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final routes = data['routes'] as List;

        if (routes.isEmpty) {
          _logger.w('No routes found');
          return null;
        }

        final route = routes[0];
        return DirectionsResult(
          polyline: route['geometry'] as String,
          distanceMeters: (route['distance'] as num).toInt(),
          durationSeconds: (route['duration'] as num).toInt(),
        );
      }

      _logger.w('Directions API returned ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('Get directions error: $e');
      return null;
    }
  }

  /// Calculate ETA based on current position and destination.
  Future<DateTime?> calculateETA({
    required double currentLat,
    required double currentLng,
    required double destLat,
    required double destLng,
  }) async {
    final result = await getDirections(
      originLat: currentLat,
      originLng: currentLng,
      destLat: destLat,
      destLng: destLng,
    );

    if (result != null) {
      return DateTime.now().add(Duration(seconds: result.durationSeconds));
    }
    return null;
  }

  /// Reverse geocode coordinates to an address.
  Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final url =
          '${AppConstants.mapboxBaseUrl}/geocoding/v5/mapbox.places/$lng,$lat.json';

      final response = await _dio.get(
        url,
        queryParameters: {
          'access_token': _accessToken,
          'types': 'address,place',
          'limit': 1,
        },
      );

      if (response.statusCode == 200) {
        final features = response.data['features'] as List;
        if (features.isNotEmpty) {
          return features[0]['place_name'] as String;
        }
      }

      return null;
    } catch (e) {
      _logger.e('Reverse geocode error: $e');
      return null;
    }
  }

  /// Forward geocode an address to coordinates.
  Future<List<GeocodingResult>> forwardGeocode(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    try {
      final url =
          '${AppConstants.mapboxBaseUrl}/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json';

      final queryParams = <String, dynamic>{
        'access_token': _accessToken,
        'limit': 5,
        'types': 'address,place,poi',
        'country': 'eg', // 🌍 Restrict to Egypt
      };

      if (proximityLat != null && proximityLng != null) {
        // 🔄 Sort by proximity using current location
        queryParams['proximity'] = '$proximityLng,$proximityLat';
      }

      final response = await _dio.get(url, queryParameters: queryParams);

      if (response.statusCode == 200) {
        final features = response.data['features'] as List;
        return features.map((f) {
          final coords = f['center'] as List;
          return GeocodingResult(
            placeName: f['place_name'] as String,
            latitude: coords[1] as double,
            longitude: coords[0] as double,
          );
        }).toList();
      }

      return [];
    } catch (e) {
      _logger.e('Forward geocode error: $e');
      return [];
    }
  }

  /// Optimize route for multiple stops (Vehicle Routing).
  /// Uses Mapbox Optimization API v1.
  Future<OptimizationResult?> optimizeRoute({
    required List<({double lat, double lng})> waypoints,
  }) async {
    try {
      if (waypoints.length < 2) return null;

      final coordinates = waypoints.map((w) => '${w.lng},${w.lat}').join(';');

      final url =
          '${AppConstants.mapboxBaseUrl}${AppConstants.mapboxOptimizationEndpoint}'
          '/$coordinates';

      final response = await _dio.get(
        url,
        queryParameters: {
          'access_token': _accessToken,
          'geometries': 'polyline6',
          'overview': 'full',
          'steps': 'false',
          'roundtrip': 'false',
          'source': 'first',
          'destination': 'last',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final trips = data['trips'] as List?;

        if (trips == null || trips.isEmpty) {
          _logger.w('No optimized route found');
          return null;
        }

        final trip = trips[0];
        final wayPointOrder = (data['waypoints'] as List)
            .map((w) => w['waypoint_index'] as int)
            .toList();

        return OptimizationResult(
          polyline: trip['geometry'] as String,
          distanceMeters: (trip['distance'] as num).toInt(),
          durationSeconds: (trip['duration'] as num).toInt(),
          waypointOrder: wayPointOrder,
        );
      }

      return null;
    } catch (e) {
      _logger.e('Optimize route error: $e');
      return null;
    }
  }
}

/// Result from Mapbox Directions API.
class DirectionsResult {
  final String polyline;
  final int distanceMeters;
  final int durationSeconds;

  const DirectionsResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Result from Mapbox Geocoding API.
class GeocodingResult {
  final String placeName;
  final double latitude;
  final double longitude;

  const GeocodingResult({
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });
}

/// Result from Mapbox Optimization API.
class OptimizationResult {
  final String polyline;
  final int distanceMeters;
  final int durationSeconds;
  final List<int> waypointOrder;

  const OptimizationResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.waypointOrder,
  });
}
