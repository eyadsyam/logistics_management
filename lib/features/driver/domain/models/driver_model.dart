import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_model.freezed.dart';
part 'driver_model.g.dart';

/// Driver entity with real-time location tracking fields.
@freezed
abstract class DriverModel with _$DriverModel {
  const factory DriverModel({
    required String id,
    required String name,
    required String phone,
    String? email,
    @Default(false) bool isOnline,
    GeoPoint? currentLocation,
    DateTime? lastUpdated,
    String? currentShipmentId,
    @Default(0) int totalTrips,
    @Default(0.0) double rating,
  }) = _DriverModel;

  factory DriverModel.fromJson(Map<String, dynamic> json) =>
      _$DriverModelFromJson(json);
}

/// Lightweight geo point model for Freezed compatibility.
@freezed
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({
    required double latitude,
    required double longitude,
  }) = _GeoPoint;

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      _$GeoPointFromJson(json);
}
