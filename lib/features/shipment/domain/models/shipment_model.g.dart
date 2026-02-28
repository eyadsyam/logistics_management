// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shipment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShipmentModelImpl _$$ShipmentModelImplFromJson(Map<String, dynamic> json) =>
    _$ShipmentModelImpl(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      driverId: json['driverId'] as String?,
      status: json['status'] as String,
      origin: ShipmentLocation.fromJson(json['origin'] as Map<String, dynamic>),
      destination: ShipmentLocation.fromJson(
        json['destination'] as Map<String, dynamic>,
      ),
      polyline: json['polyline'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      etaTimestamp: json['etaTimestamp'] == null
          ? null
          : DateTime.parse(json['etaTimestamp'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      clientName: json['clientName'] as String?,
      driverName: json['driverName'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$ShipmentModelImplToJson(_$ShipmentModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'driverId': instance.driverId,
      'status': instance.status,
      'origin': instance.origin,
      'destination': instance.destination,
      'polyline': instance.polyline,
      'distanceMeters': instance.distanceMeters,
      'durationSeconds': instance.durationSeconds,
      'etaTimestamp': instance.etaTimestamp?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'clientName': instance.clientName,
      'driverName': instance.driverName,
      'notes': instance.notes,
    };

_$ShipmentLocationImpl _$$ShipmentLocationImplFromJson(
  Map<String, dynamic> json,
) => _$ShipmentLocationImpl(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  address: json['address'] as String,
  city: json['city'] as String?,
  postalCode: json['postalCode'] as String?,
);

Map<String, dynamic> _$$ShipmentLocationImplToJson(
  _$ShipmentLocationImpl instance,
) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'address': instance.address,
  'city': instance.city,
  'postalCode': instance.postalCode,
};

_$LocationPointImpl _$$LocationPointImplFromJson(Map<String, dynamic> json) =>
    _$LocationPointImpl(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
    );

Map<String, dynamic> _$$LocationPointImplToJson(_$LocationPointImpl instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'speed': instance.speed,
      'accuracy': instance.accuracy,
      'timestamp': instance.timestamp.toIso8601String(),
      'isSynced': instance.isSynced,
    };
