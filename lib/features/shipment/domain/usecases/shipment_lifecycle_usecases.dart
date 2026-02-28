import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../models/shipment_model.dart';
import '../repositories/shipment_repository.dart';

/// Start the shipment trip (driver has picked up cargo).
class StartShipmentUseCase implements UseCase<ShipmentModel, String> {
  final ShipmentRepository repository;

  const StartShipmentUseCase(this.repository);

  @override
  Future<Either<Failure, ShipmentModel>> call(String shipmentId) {
    return repository.startShipment(shipmentId);
  }
}

/// Complete the shipment trip (driver delivered cargo).
class CompleteShipmentUseCase implements UseCase<ShipmentModel, String> {
  final ShipmentRepository repository;

  const CompleteShipmentUseCase(this.repository);

  @override
  Future<Either<Failure, ShipmentModel>> call(String shipmentId) {
    return repository.completeShipment(shipmentId);
  }
}

/// Cancel a shipment (client, only if status is pending).
class CancelShipmentUseCase implements UseCase<void, String> {
  final ShipmentRepository repository;

  const CancelShipmentUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String shipmentId) {
    return repository.cancelShipment(shipmentId);
  }
}
