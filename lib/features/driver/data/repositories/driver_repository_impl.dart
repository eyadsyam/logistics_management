import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/driver_model.dart';
import '../../domain/repositories/driver_repository.dart';

/// Firebase Firestore implementation of DriverRepository.
class DriverRepositoryImpl implements DriverRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  DriverRepositoryImpl({
    required FirebaseFirestore firestore,
    required Logger logger,
  }) : _firestore = firestore,
       _logger = logger;

  CollectionReference<Map<String, dynamic>> get _driversRef =>
      _firestore.collection(AppConstants.driversCollection);

  @override
  Future<Either<Failure, DriverModel>> getDriver(String driverId) async {
    try {
      final doc = await _driversRef.doc(driverId).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'Driver not found'));
      }

      return Right(_docToDriver(doc));
    } catch (e) {
      _logger.e('Get driver error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<DriverModel> streamDriver(String driverId) {
    return _driversRef.doc(driverId).snapshots().map(_docToDriver);
  }

  @override
  Future<Either<Failure, void>> setOnlineStatus({
    required String driverId,
    required bool isOnline,
  }) async {
    try {
      await _driversRef.doc(driverId).update({
        'isOnline': isOnline,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _logger.i('Driver $driverId is now ${isOnline ? "online" : "offline"}');
      return const Right(null);
    } catch (e) {
      _logger.e('Set online status error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateLocation({
    required String driverId,
    required GeoPoint location,
  }) async {
    try {
      await _driversRef.doc(driverId).update({
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return const Right(null);
    } catch (e) {
      _logger.e('Update location error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DriverModel>>> getOnlineDrivers() async {
    try {
      final snapshot = await _driversRef
          .where('isOnline', isEqualTo: true)
          .get();

      final drivers = snapshot.docs.map(_docToDriver).toList();
      return Right(drivers);
    } catch (e) {
      _logger.e('Get online drivers error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<DriverModel>> streamOnlineDrivers() {
    return _driversRef
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToDriver).toList());
  }

  @override
  Future<Either<Failure, void>> createDriverProfile({
    required String driverId,
    required String name,
    required String phone,
    String? email,
  }) async {
    try {
      await _driversRef.doc(driverId).set({
        'id': driverId,
        'name': name,
        'phone': phone,
        'email': email,
        'isOnline': false,
        'currentLocation': null,
        'lastUpdated': FieldValue.serverTimestamp(),
        'currentShipmentId': null,
        'totalTrips': 0,
        'rating': 0.0,
      });

      _logger.i('Driver profile created: $driverId');
      return const Right(null);
    } catch (e) {
      _logger.e('Create driver profile error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCurrentShipment({
    required String driverId,
    String? shipmentId,
  }) async {
    try {
      await _driversRef.doc(driverId).update({
        'currentShipmentId': shipmentId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return const Right(null);
    } catch (e) {
      _logger.e('Update current shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  DriverModel _docToDriver(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    data['id'] = doc.id;

    // Handle Firestore timestamp
    if (data['lastUpdated'] is Timestamp) {
      data['lastUpdated'] = (data['lastUpdated'] as Timestamp)
          .toDate()
          .toIso8601String();
    }

    return DriverModel.fromJson(data);
  }
}
