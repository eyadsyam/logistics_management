import 'package:freezed_annotation/freezed_annotation.dart';

part 'shipment_model.freezed.dart';
part 'shipment_model.g.dart';

/// Core shipment entity representing a logistics order from creation to completion.
@freezed
abstract class ShipmentModel with _$ShipmentModel {
  const factory ShipmentModel({
    required String id,
    required String clientId,
    String? driverId,
    required String status,
    required ShipmentLocation origin,
    required ShipmentLocation destination,
    String? polyline,
    @Default(0) int distanceMeters,
    @Default(0) int durationSeconds,
    DateTime? etaTimestamp,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? clientName,
    String? driverName,
    String? notes,
    @Default(false) bool isCleared,
    @Default(0.0) double price,
    // ── Factory-first routing fields ──
    /// The Edita factory code (e.g. "E06", "E10")
    String? factoryId,

    /// The factory pickup location (driver goes here first)
    ShipmentLocation? factoryLocation,

    /// Current trip phase: "pickup" (driver → factory) or "delivery" (factory → destination)
    @Default('pickup') String tripPhase,

    /// Polyline from factory to destination (2nd leg)
    String? deliveryPolyline,

    /// Distance from factory to destination
    @Default(0) int deliveryDistanceMeters,

    /// Duration from factory to destination
    @Default(0) int deliveryDurationSeconds,
  }) = _ShipmentModel;

  factory ShipmentModel.fromJson(Map<String, dynamic> json) =>
      _$ShipmentModelFromJson(json);
}

/// Shipment origin/destination location with address and coordinates.
@freezed
abstract class ShipmentLocation with _$ShipmentLocation {
  const factory ShipmentLocation({
    required double latitude,
    required double longitude,
    required String address,
    String? city,
    String? postalCode,
  }) = _ShipmentLocation;

  factory ShipmentLocation.fromJson(Map<String, dynamic> json) =>
      _$ShipmentLocationFromJson(json);
}

/// Location history point recorded during active trips.
@freezed
abstract class LocationPoint with _$LocationPoint {
  const factory LocationPoint({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
    required DateTime timestamp,
    @Default(false) bool isSynced,
  }) = _LocationPoint;

  factory LocationPoint.fromJson(Map<String, dynamic> json) =>
      _$LocationPointFromJson(json);
}
