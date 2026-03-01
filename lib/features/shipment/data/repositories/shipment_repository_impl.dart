import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/shipment_model.dart';
import '../../domain/repositories/shipment_repository.dart';

/// Firebase Firestore implementation of ShipmentRepository.
/// Manages all shipment CRUD, status transitions, and location tracking.
class ShipmentRepositoryImpl implements ShipmentRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  ShipmentRepositoryImpl({
    required FirebaseFirestore firestore,
    required Logger logger,
  }) : _firestore = firestore,
       _logger = logger;

  CollectionReference<Map<String, dynamic>> get _shipmentsRef =>
      _firestore.collection(AppConstants.shipmentsCollection);

  @override
  Future<Either<Failure, ShipmentModel>> createShipment({
    required String clientId,
    required ShipmentLocation origin,
    required ShipmentLocation destination,
    String? notes,
    double price = 0.0,
    String? polyline,
    int distanceMeters = 0,
    int durationSeconds = 0,
  }) async {
    try {
      final docRef = _shipmentsRef.doc();
      final now = DateTime.now();

      final shipment = ShipmentModel(
        id: docRef.id,
        clientId: clientId,
        status: AppConstants.statusPending,
        origin: origin,
        destination: destination,
        notes: notes,
        createdAt: now,
        price: price,
        polyline: polyline,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );

      final shipmentJson = shipment.toJson();
      shipmentJson['origin'] = shipment.origin.toJson();
      shipmentJson['destination'] = shipment.destination.toJson();

      await docRef.set({
        ...shipmentJson,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Shipment created: ${docRef.id}');
      return Right(shipment);
    } catch (e) {
      _logger.e('Create shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ShipmentModel>> getShipment(String shipmentId) async {
    try {
      final doc = await _shipmentsRef.doc(shipmentId).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'Shipment not found'));
      }

      return Right(_docToShipment(doc));
    } catch (e) {
      _logger.e('Get shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<ShipmentModel> streamShipment(String shipmentId) {
    return _shipmentsRef.doc(shipmentId).snapshots().map(_docToShipment);
  }

  @override
  Future<Either<Failure, List<ShipmentModel>>> getClientShipments(
    String clientId,
  ) async {
    try {
      final snapshot = await _shipmentsRef
          .where('clientId', isEqualTo: clientId)
          .get();

      final shipments = snapshot.docs.map(_docToShipment).toList();
      shipments.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
      return Right(shipments);
    } catch (e) {
      _logger.e('Get client shipments error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ShipmentModel>> streamClientShipments(String clientId) {
    return _shipmentsRef.where('clientId', isEqualTo: clientId).snapshots().map(
      (snapshot) {
        final list = snapshot.docs.map(_docToShipment).toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          ),
        );
        return list;
      },
    );
  }

  @override
  Future<Either<Failure, List<ShipmentModel>>> getPendingShipments() async {
    try {
      final snapshot = await _shipmentsRef
          .where('status', isEqualTo: AppConstants.statusPending)
          .get();

      final shipments = snapshot.docs.map(_docToShipment).toList();
      shipments.sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );
      return Right(shipments);
    } catch (e) {
      _logger.e('Get pending shipments error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ShipmentModel>> streamPendingShipments() {
    return _shipmentsRef
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map(_docToShipment).toList();
          list.sort(
            (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            ),
          );
          return list;
        });
  }

  @override
  Future<Either<Failure, List<ShipmentModel>>> getAllShipments() async {
    try {
      final snapshot = await _shipmentsRef
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final shipments = snapshot.docs.map(_docToShipment).toList();
      return Right(shipments);
    } catch (e) {
      _logger.e('Get all shipments error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<ShipmentModel>> streamAllActiveShipments() {
    return _shipmentsRef
        .where(
          'status',
          whereIn: [
            AppConstants.statusPending,
            AppConstants.statusAccepted,
            AppConstants.statusInProgress,
          ],
        )
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map(_docToShipment).toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
              a.createdAt ?? DateTime.now(),
            ),
          );
          return list;
        });
  }

  @override
  Future<Either<Failure, ShipmentModel>> acceptShipment({
    required String shipmentId,
    required String driverId,
    required String driverName,
  }) async {
    try {
      // Use transaction for atomicity
      final result = await _firestore.runTransaction<ShipmentModel>((tx) async {
        final doc = await tx.get(_shipmentsRef.doc(shipmentId));

        if (!doc.exists) {
          throw Exception('Shipment not found');
        }

        final data = doc.data()!;
        if (data['status'] != AppConstants.statusPending) {
          throw Exception('Shipment is no longer available');
        }

        tx.update(_shipmentsRef.doc(shipmentId), {
          'driverId': driverId,
          'driverName': driverName,
          'status': AppConstants.statusAccepted,
        });

        data['driverId'] = driverId;
        data['driverName'] = driverName;
        data['status'] = AppConstants.statusAccepted;
        data['id'] = shipmentId;

        return _mapToShipment(data);
      });

      _logger.i('Shipment $shipmentId accepted by driver $driverId');
      return Right(result);
    } catch (e) {
      _logger.e('Accept shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ShipmentModel>> startShipment(
    String shipmentId,
  ) async {
    try {
      final now = DateTime.now();

      await _shipmentsRef.doc(shipmentId).update({
        'status': AppConstants.statusInProgress,
        'startedAt': Timestamp.fromDate(now),
      });

      final doc = await _shipmentsRef.doc(shipmentId).get();
      _logger.i('Shipment $shipmentId started');
      return Right(_docToShipment(doc));
    } catch (e) {
      _logger.e('Start shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ShipmentModel>> completeShipment(
    String shipmentId,
  ) async {
    try {
      final now = DateTime.now();

      await _shipmentsRef.doc(shipmentId).update({
        'status': AppConstants.statusCompleted,
        'completedAt': Timestamp.fromDate(now),
      });

      final doc = await _shipmentsRef.doc(shipmentId).get();
      _logger.i('Shipment $shipmentId completed');
      return Right(_docToShipment(doc));
    } catch (e) {
      _logger.e('Complete shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelShipment(String shipmentId) async {
    try {
      final doc = await _shipmentsRef.doc(shipmentId).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'Shipment not found'));
      }

      final status = doc.data()!['status'] as String;
      if (status == AppConstants.statusInProgress) {
        return const Left(
          ServerFailure(message: 'Cannot cancel an in-progress shipment'),
        );
      }

      await _shipmentsRef.doc(shipmentId).update({
        'status': AppConstants.statusCancelled,
      });

      _logger.i('Shipment $shipmentId cancelled');
      return const Right(null);
    } catch (e) {
      _logger.e('Cancel shipment error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShipmentRoute({
    required String shipmentId,
    required String polyline,
    required int distanceMeters,
    required int durationSeconds,
    required DateTime etaTimestamp,
  }) async {
    try {
      await _shipmentsRef.doc(shipmentId).update({
        'polyline': polyline,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'etaTimestamp': Timestamp.fromDate(etaTimestamp),
      });

      return const Right(null);
    } catch (e) {
      _logger.e('Update shipment route error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addLocationPoint({
    required String shipmentId,
    required LocationPoint point,
  }) async {
    try {
      await _shipmentsRef
          .doc(shipmentId)
          .collection(AppConstants.locationHistorySubcollection)
          .add({
            ...point.toJson(),
            'timestamp': Timestamp.fromDate(point.timestamp),
          });

      return const Right(null);
    } catch (e) {
      _logger.e('Add location point error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<LocationPoint>> streamLocationHistory(String shipmentId) {
    return _shipmentsRef
        .doc(shipmentId)
        .collection(AppConstants.locationHistorySubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Convert Firestore timestamp to DateTime
            if (data['timestamp'] is Timestamp) {
              data['timestamp'] = (data['timestamp'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }
            return LocationPoint.fromJson(data);
          }).toList();
        });
  }

  /// Convert a Firestore document snapshot to ShipmentModel.
  ShipmentModel _docToShipment(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    data['id'] = doc.id;
    return _mapToShipment(data);
  }

  @override
  Future<Either<Failure, void>> clearCompletedShipments(String clientId) async {
    try {
      final snapshot = await _firestore
          .collection('shipments')
          .where('clientId', isEqualTo: clientId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        if (doc.data()['status'] == AppConstants.statusCompleted ||
            doc.data()['status'] == AppConstants.statusCancelled) {
          batch.update(doc.reference, {'isCleared': true});
        }
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      _logger.e('Clear completed shipments error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Map a Firestore data map to ShipmentModel, handling Timestamp conversions.
  ShipmentModel _mapToShipment(Map<String, dynamic> data) {
    // Convert Firestore timestamps to ISO strings for Freezed
    for (final field in [
      'createdAt',
      'startedAt',
      'completedAt',
      'etaTimestamp',
    ]) {
      if (data[field] is Timestamp) {
        data[field] = (data[field] as Timestamp).toDate().toIso8601String();
      }
    }

    return ShipmentModel.fromJson(data);
  }
}
