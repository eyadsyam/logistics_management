// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shipment_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ShipmentModel _$ShipmentModelFromJson(Map<String, dynamic> json) {
  return _ShipmentModel.fromJson(json);
}

/// @nodoc
mixin _$ShipmentModel {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  String? get driverId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  ShipmentLocation get origin => throw _privateConstructorUsedError;
  ShipmentLocation get destination => throw _privateConstructorUsedError;
  String? get polyline => throw _privateConstructorUsedError;
  int get distanceMeters => throw _privateConstructorUsedError;
  int get durationSeconds => throw _privateConstructorUsedError;
  DateTime? get etaTimestamp => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String? get clientName => throw _privateConstructorUsedError;
  String? get driverName => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this ShipmentModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShipmentModelCopyWith<ShipmentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShipmentModelCopyWith<$Res> {
  factory $ShipmentModelCopyWith(
    ShipmentModel value,
    $Res Function(ShipmentModel) then,
  ) = _$ShipmentModelCopyWithImpl<$Res, ShipmentModel>;
  @useResult
  $Res call({
    String id,
    String clientId,
    String? driverId,
    String status,
    ShipmentLocation origin,
    ShipmentLocation destination,
    String? polyline,
    int distanceMeters,
    int durationSeconds,
    DateTime? etaTimestamp,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? clientName,
    String? driverName,
    String? notes,
  });

  $ShipmentLocationCopyWith<$Res> get origin;
  $ShipmentLocationCopyWith<$Res> get destination;
}

/// @nodoc
class _$ShipmentModelCopyWithImpl<$Res, $Val extends ShipmentModel>
    implements $ShipmentModelCopyWith<$Res> {
  _$ShipmentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? driverId = freezed,
    Object? status = null,
    Object? origin = null,
    Object? destination = null,
    Object? polyline = freezed,
    Object? distanceMeters = null,
    Object? durationSeconds = null,
    Object? etaTimestamp = freezed,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? clientName = freezed,
    Object? driverName = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            driverId: freezed == driverId
                ? _value.driverId
                : driverId // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            origin: null == origin
                ? _value.origin
                : origin // ignore: cast_nullable_to_non_nullable
                      as ShipmentLocation,
            destination: null == destination
                ? _value.destination
                : destination // ignore: cast_nullable_to_non_nullable
                      as ShipmentLocation,
            polyline: freezed == polyline
                ? _value.polyline
                : polyline // ignore: cast_nullable_to_non_nullable
                      as String?,
            distanceMeters: null == distanceMeters
                ? _value.distanceMeters
                : distanceMeters // ignore: cast_nullable_to_non_nullable
                      as int,
            durationSeconds: null == durationSeconds
                ? _value.durationSeconds
                : durationSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
            etaTimestamp: freezed == etaTimestamp
                ? _value.etaTimestamp
                : etaTimestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            clientName: freezed == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                      as String?,
            driverName: freezed == driverName
                ? _value.driverName
                : driverName // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShipmentLocationCopyWith<$Res> get origin {
    return $ShipmentLocationCopyWith<$Res>(_value.origin, (value) {
      return _then(_value.copyWith(origin: value) as $Val);
    });
  }

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShipmentLocationCopyWith<$Res> get destination {
    return $ShipmentLocationCopyWith<$Res>(_value.destination, (value) {
      return _then(_value.copyWith(destination: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ShipmentModelImplCopyWith<$Res>
    implements $ShipmentModelCopyWith<$Res> {
  factory _$$ShipmentModelImplCopyWith(
    _$ShipmentModelImpl value,
    $Res Function(_$ShipmentModelImpl) then,
  ) = __$$ShipmentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String clientId,
    String? driverId,
    String status,
    ShipmentLocation origin,
    ShipmentLocation destination,
    String? polyline,
    int distanceMeters,
    int durationSeconds,
    DateTime? etaTimestamp,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? clientName,
    String? driverName,
    String? notes,
  });

  @override
  $ShipmentLocationCopyWith<$Res> get origin;
  @override
  $ShipmentLocationCopyWith<$Res> get destination;
}

/// @nodoc
class __$$ShipmentModelImplCopyWithImpl<$Res>
    extends _$ShipmentModelCopyWithImpl<$Res, _$ShipmentModelImpl>
    implements _$$ShipmentModelImplCopyWith<$Res> {
  __$$ShipmentModelImplCopyWithImpl(
    _$ShipmentModelImpl _value,
    $Res Function(_$ShipmentModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? driverId = freezed,
    Object? status = null,
    Object? origin = null,
    Object? destination = null,
    Object? polyline = freezed,
    Object? distanceMeters = null,
    Object? durationSeconds = null,
    Object? etaTimestamp = freezed,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? clientName = freezed,
    Object? driverName = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$ShipmentModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        driverId: freezed == driverId
            ? _value.driverId
            : driverId // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _value.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as ShipmentLocation,
        destination: null == destination
            ? _value.destination
            : destination // ignore: cast_nullable_to_non_nullable
                  as ShipmentLocation,
        polyline: freezed == polyline
            ? _value.polyline
            : polyline // ignore: cast_nullable_to_non_nullable
                  as String?,
        distanceMeters: null == distanceMeters
            ? _value.distanceMeters
            : distanceMeters // ignore: cast_nullable_to_non_nullable
                  as int,
        durationSeconds: null == durationSeconds
            ? _value.durationSeconds
            : durationSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
        etaTimestamp: freezed == etaTimestamp
            ? _value.etaTimestamp
            : etaTimestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        clientName: freezed == clientName
            ? _value.clientName
            : clientName // ignore: cast_nullable_to_non_nullable
                  as String?,
        driverName: freezed == driverName
            ? _value.driverName
            : driverName // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShipmentModelImpl implements _ShipmentModel {
  const _$ShipmentModelImpl({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.status,
    required this.origin,
    required this.destination,
    this.polyline,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.etaTimestamp,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.clientName,
    this.driverName,
    this.notes,
  });

  factory _$ShipmentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShipmentModelImplFromJson(json);

  @override
  final String id;
  @override
  final String clientId;
  @override
  final String? driverId;
  @override
  final String status;
  @override
  final ShipmentLocation origin;
  @override
  final ShipmentLocation destination;
  @override
  final String? polyline;
  @override
  @JsonKey()
  final int distanceMeters;
  @override
  @JsonKey()
  final int durationSeconds;
  @override
  final DateTime? etaTimestamp;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;
  @override
  final String? clientName;
  @override
  final String? driverName;
  @override
  final String? notes;

  @override
  String toString() {
    return 'ShipmentModel(id: $id, clientId: $clientId, driverId: $driverId, status: $status, origin: $origin, destination: $destination, polyline: $polyline, distanceMeters: $distanceMeters, durationSeconds: $durationSeconds, etaTimestamp: $etaTimestamp, createdAt: $createdAt, startedAt: $startedAt, completedAt: $completedAt, clientName: $clientName, driverName: $driverName, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShipmentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.polyline, polyline) ||
                other.polyline == polyline) &&
            (identical(other.distanceMeters, distanceMeters) ||
                other.distanceMeters == distanceMeters) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.etaTimestamp, etaTimestamp) ||
                other.etaTimestamp == etaTimestamp) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            (identical(other.driverName, driverName) ||
                other.driverName == driverName) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    clientId,
    driverId,
    status,
    origin,
    destination,
    polyline,
    distanceMeters,
    durationSeconds,
    etaTimestamp,
    createdAt,
    startedAt,
    completedAt,
    clientName,
    driverName,
    notes,
  );

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShipmentModelImplCopyWith<_$ShipmentModelImpl> get copyWith =>
      __$$ShipmentModelImplCopyWithImpl<_$ShipmentModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShipmentModelImplToJson(this);
  }
}

abstract class _ShipmentModel implements ShipmentModel {
  const factory _ShipmentModel({
    required final String id,
    required final String clientId,
    final String? driverId,
    required final String status,
    required final ShipmentLocation origin,
    required final ShipmentLocation destination,
    final String? polyline,
    final int distanceMeters,
    final int durationSeconds,
    final DateTime? etaTimestamp,
    final DateTime? createdAt,
    final DateTime? startedAt,
    final DateTime? completedAt,
    final String? clientName,
    final String? driverName,
    final String? notes,
  }) = _$ShipmentModelImpl;

  factory _ShipmentModel.fromJson(Map<String, dynamic> json) =
      _$ShipmentModelImpl.fromJson;

  @override
  String get id;
  @override
  String get clientId;
  @override
  String? get driverId;
  @override
  String get status;
  @override
  ShipmentLocation get origin;
  @override
  ShipmentLocation get destination;
  @override
  String? get polyline;
  @override
  int get distanceMeters;
  @override
  int get durationSeconds;
  @override
  DateTime? get etaTimestamp;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get completedAt;
  @override
  String? get clientName;
  @override
  String? get driverName;
  @override
  String? get notes;

  /// Create a copy of ShipmentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShipmentModelImplCopyWith<_$ShipmentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShipmentLocation _$ShipmentLocationFromJson(Map<String, dynamic> json) {
  return _ShipmentLocation.fromJson(json);
}

/// @nodoc
mixin _$ShipmentLocation {
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get postalCode => throw _privateConstructorUsedError;

  /// Serializes this ShipmentLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShipmentLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShipmentLocationCopyWith<ShipmentLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShipmentLocationCopyWith<$Res> {
  factory $ShipmentLocationCopyWith(
    ShipmentLocation value,
    $Res Function(ShipmentLocation) then,
  ) = _$ShipmentLocationCopyWithImpl<$Res, ShipmentLocation>;
  @useResult
  $Res call({
    double latitude,
    double longitude,
    String address,
    String? city,
    String? postalCode,
  });
}

/// @nodoc
class _$ShipmentLocationCopyWithImpl<$Res, $Val extends ShipmentLocation>
    implements $ShipmentLocationCopyWith<$Res> {
  _$ShipmentLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShipmentLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
    Object? city = freezed,
    Object? postalCode = freezed,
  }) {
    return _then(
      _value.copyWith(
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            postalCode: freezed == postalCode
                ? _value.postalCode
                : postalCode // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShipmentLocationImplCopyWith<$Res>
    implements $ShipmentLocationCopyWith<$Res> {
  factory _$$ShipmentLocationImplCopyWith(
    _$ShipmentLocationImpl value,
    $Res Function(_$ShipmentLocationImpl) then,
  ) = __$$ShipmentLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double latitude,
    double longitude,
    String address,
    String? city,
    String? postalCode,
  });
}

/// @nodoc
class __$$ShipmentLocationImplCopyWithImpl<$Res>
    extends _$ShipmentLocationCopyWithImpl<$Res, _$ShipmentLocationImpl>
    implements _$$ShipmentLocationImplCopyWith<$Res> {
  __$$ShipmentLocationImplCopyWithImpl(
    _$ShipmentLocationImpl _value,
    $Res Function(_$ShipmentLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShipmentLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? address = null,
    Object? city = freezed,
    Object? postalCode = freezed,
  }) {
    return _then(
      _$ShipmentLocationImpl(
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        postalCode: freezed == postalCode
            ? _value.postalCode
            : postalCode // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShipmentLocationImpl implements _ShipmentLocation {
  const _$ShipmentLocationImpl({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.postalCode,
  });

  factory _$ShipmentLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShipmentLocationImplFromJson(json);

  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String address;
  @override
  final String? city;
  @override
  final String? postalCode;

  @override
  String toString() {
    return 'ShipmentLocation(latitude: $latitude, longitude: $longitude, address: $address, city: $city, postalCode: $postalCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShipmentLocationImpl &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.postalCode, postalCode) ||
                other.postalCode == postalCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, latitude, longitude, address, city, postalCode);

  /// Create a copy of ShipmentLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShipmentLocationImplCopyWith<_$ShipmentLocationImpl> get copyWith =>
      __$$ShipmentLocationImplCopyWithImpl<_$ShipmentLocationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShipmentLocationImplToJson(this);
  }
}

abstract class _ShipmentLocation implements ShipmentLocation {
  const factory _ShipmentLocation({
    required final double latitude,
    required final double longitude,
    required final String address,
    final String? city,
    final String? postalCode,
  }) = _$ShipmentLocationImpl;

  factory _ShipmentLocation.fromJson(Map<String, dynamic> json) =
      _$ShipmentLocationImpl.fromJson;

  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String get address;
  @override
  String? get city;
  @override
  String? get postalCode;

  /// Create a copy of ShipmentLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShipmentLocationImplCopyWith<_$ShipmentLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LocationPoint _$LocationPointFromJson(Map<String, dynamic> json) {
  return _LocationPoint.fromJson(json);
}

/// @nodoc
mixin _$LocationPoint {
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  double get speed => throw _privateConstructorUsedError;
  double get accuracy => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isSynced => throw _privateConstructorUsedError;

  /// Serializes this LocationPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LocationPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LocationPointCopyWith<LocationPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationPointCopyWith<$Res> {
  factory $LocationPointCopyWith(
    LocationPoint value,
    $Res Function(LocationPoint) then,
  ) = _$LocationPointCopyWithImpl<$Res, LocationPoint>;
  @useResult
  $Res call({
    double latitude,
    double longitude,
    double speed,
    double accuracy,
    DateTime timestamp,
    bool isSynced,
  });
}

/// @nodoc
class _$LocationPointCopyWithImpl<$Res, $Val extends LocationPoint>
    implements $LocationPointCopyWith<$Res> {
  _$LocationPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LocationPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? speed = null,
    Object? accuracy = null,
    Object? timestamp = null,
    Object? isSynced = null,
  }) {
    return _then(
      _value.copyWith(
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
            speed: null == speed
                ? _value.speed
                : speed // ignore: cast_nullable_to_non_nullable
                      as double,
            accuracy: null == accuracy
                ? _value.accuracy
                : accuracy // ignore: cast_nullable_to_non_nullable
                      as double,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isSynced: null == isSynced
                ? _value.isSynced
                : isSynced // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LocationPointImplCopyWith<$Res>
    implements $LocationPointCopyWith<$Res> {
  factory _$$LocationPointImplCopyWith(
    _$LocationPointImpl value,
    $Res Function(_$LocationPointImpl) then,
  ) = __$$LocationPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double latitude,
    double longitude,
    double speed,
    double accuracy,
    DateTime timestamp,
    bool isSynced,
  });
}

/// @nodoc
class __$$LocationPointImplCopyWithImpl<$Res>
    extends _$LocationPointCopyWithImpl<$Res, _$LocationPointImpl>
    implements _$$LocationPointImplCopyWith<$Res> {
  __$$LocationPointImplCopyWithImpl(
    _$LocationPointImpl _value,
    $Res Function(_$LocationPointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? speed = null,
    Object? accuracy = null,
    Object? timestamp = null,
    Object? isSynced = null,
  }) {
    return _then(
      _$LocationPointImpl(
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
        speed: null == speed
            ? _value.speed
            : speed // ignore: cast_nullable_to_non_nullable
                  as double,
        accuracy: null == accuracy
            ? _value.accuracy
            : accuracy // ignore: cast_nullable_to_non_nullable
                  as double,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isSynced: null == isSynced
            ? _value.isSynced
            : isSynced // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LocationPointImpl implements _LocationPoint {
  const _$LocationPointImpl({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
    this.isSynced = false,
  });

  factory _$LocationPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$LocationPointImplFromJson(json);

  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final double speed;
  @override
  final double accuracy;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final bool isSynced;

  @override
  String toString() {
    return 'LocationPoint(latitude: $latitude, longitude: $longitude, speed: $speed, accuracy: $accuracy, timestamp: $timestamp, isSynced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationPointImpl &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.accuracy, accuracy) ||
                other.accuracy == accuracy) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isSynced, isSynced) ||
                other.isSynced == isSynced));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    latitude,
    longitude,
    speed,
    accuracy,
    timestamp,
    isSynced,
  );

  /// Create a copy of LocationPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationPointImplCopyWith<_$LocationPointImpl> get copyWith =>
      __$$LocationPointImplCopyWithImpl<_$LocationPointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LocationPointImplToJson(this);
  }
}

abstract class _LocationPoint implements LocationPoint {
  const factory _LocationPoint({
    required final double latitude,
    required final double longitude,
    required final double speed,
    required final double accuracy,
    required final DateTime timestamp,
    final bool isSynced,
  }) = _$LocationPointImpl;

  factory _LocationPoint.fromJson(Map<String, dynamic> json) =
      _$LocationPointImpl.fromJson;

  @override
  double get latitude;
  @override
  double get longitude;
  @override
  double get speed;
  @override
  double get accuracy;
  @override
  DateTime get timestamp;
  @override
  bool get isSynced;

  /// Create a copy of LocationPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationPointImplCopyWith<_$LocationPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
