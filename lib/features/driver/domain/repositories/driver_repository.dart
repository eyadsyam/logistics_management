import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/driver_model.dart';

/// Repository contract for driver-specific operations.
abstract class DriverRepository {
  /// Get a driver's profile data.
  Future<Either<Failure, DriverModel>> getDriver(String driverId);

  /// Stream a driver's profile for real-time status updates.
  Stream<DriverModel> streamDriver(String driverId);

  /// Toggle driver's online/offline status.
  Future<Either<Failure, void>> setOnlineStatus({
    required String driverId,
    required bool isOnline,
  });

  /// Update driver's current GPS location.
  Future<Either<Failure, void>> updateLocation({
    required String driverId,
    required GeoPoint location,
  });

  /// Get list of all online drivers (admin).
  Future<Either<Failure, List<DriverModel>>> getOnlineDrivers();

  /// Stream all online drivers (admin monitoring).
  Stream<List<DriverModel>> streamOnlineDrivers();

  /// Create driver profile during registration.
  Future<Either<Failure, void>> createDriverProfile({
    required String driverId,
    required String name,
    required String phone,
    String? email,
  });

  /// Update the current shipment assignment for the driver.
  Future<Either<Failure, void>> updateCurrentShipment({
    required String driverId,
    String? shipmentId,
  });
}
