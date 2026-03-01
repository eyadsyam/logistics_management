import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/shipment_model.dart';

/// Repository contract for shipment CRUD and tracking operations.
abstract class ShipmentRepository {
  /// Create a new shipment request.
  Future<Either<Failure, ShipmentModel>> createShipment({
    required String clientId,
    required ShipmentLocation origin,
    required ShipmentLocation destination,
    String? notes,
    double price = 0.0,
    String? polyline,
    int distanceMeters = 0,
    int durationSeconds = 0,
  });

  /// Get a single shipment by ID.
  Future<Either<Failure, ShipmentModel>> getShipment(String shipmentId);

  /// Stream a single shipment for real-time updates.
  Stream<ShipmentModel> streamShipment(String shipmentId);

  /// Get all shipments for a specific client.
  Future<Either<Failure, List<ShipmentModel>>> getClientShipments(
    String clientId,
  );

  /// Stream client's active shipments.
  Stream<List<ShipmentModel>> streamClientShipments(String clientId);

  /// Get available (pending) shipments for drivers.
  Future<Either<Failure, List<ShipmentModel>>> getPendingShipments();

  /// Stream pending shipments for driver assignment.
  Stream<List<ShipmentModel>> streamPendingShipments();

  /// Get all shipments (admin view).
  Future<Either<Failure, List<ShipmentModel>>> getAllShipments();

  /// Stream all active shipments (admin view).
  Stream<List<ShipmentModel>> streamAllActiveShipments();

  /// Assign a driver to a pending shipment.
  Future<Either<Failure, ShipmentModel>> acceptShipment({
    required String shipmentId,
    required String driverId,
    required String driverName,
  });

  /// Start the shipment trip (driver).
  Future<Either<Failure, ShipmentModel>> startShipment(String shipmentId);

  /// Complete the shipment trip (driver).
  Future<Either<Failure, ShipmentModel>> completeShipment(String shipmentId);

  /// Cancel a shipment (client, only if not started).
  Future<Either<Failure, void>> cancelShipment(String shipmentId);

  /// Update shipment route info (polyline, distance, duration).
  Future<Either<Failure, void>> updateShipmentRoute({
    required String shipmentId,
    required String polyline,
    required int distanceMeters,
    required int durationSeconds,
    required DateTime etaTimestamp,
  });

  /// Add a location point to shipment's location history.
  Future<Either<Failure, void>> addLocationPoint({
    required String shipmentId,
    required LocationPoint point,
  });

  /// Stream location history for a shipment.
  Stream<List<LocationPoint>> streamLocationHistory(String shipmentId);

  /// Clear (Delete) all completed shipments for a specific client.
  Future<Either<Failure, void>> clearCompletedShipments(String clientId);
}
