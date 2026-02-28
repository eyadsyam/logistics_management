import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../models/shipment_model.dart';
import '../repositories/shipment_repository.dart';

/// Accept a pending shipment (driver).
class AcceptShipmentUseCase
    implements UseCase<ShipmentModel, AcceptShipmentParams> {
  final ShipmentRepository repository;

  const AcceptShipmentUseCase(this.repository);

  @override
  Future<Either<Failure, ShipmentModel>> call(AcceptShipmentParams params) {
    return repository.acceptShipment(
      shipmentId: params.shipmentId,
      driverId: params.driverId,
      driverName: params.driverName,
    );
  }
}

class AcceptShipmentParams {
  final String shipmentId;
  final String driverId;
  final String driverName;

  const AcceptShipmentParams({
    required this.shipmentId,
    required this.driverId,
    required this.driverName,
  });
}
