// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DriverModelImpl _$$DriverModelImplFromJson(Map<String, dynamic> json) =>
    _$DriverModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      currentLocation: json['currentLocation'] == null
          ? null
          : GeoPoint.fromJson(json['currentLocation'] as Map<String, dynamic>),
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
      currentShipmentId: json['currentShipmentId'] as String?,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$DriverModelImplToJson(_$DriverModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
      'isOnline': instance.isOnline,
      'currentLocation': instance.currentLocation,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
      'currentShipmentId': instance.currentShipmentId,
      'totalTrips': instance.totalTrips,
      'rating': instance.rating,
    };

_$GeoPointImpl _$$GeoPointImplFromJson(Map<String, dynamic> json) =>
    _$GeoPointImpl(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$$GeoPointImplToJson(_$GeoPointImpl instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
