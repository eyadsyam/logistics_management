import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../models/shipment_model.dart';
import '../repositories/shipment_repository.dart';

/// Create a new shipment request (client).
class CreateShipmentUseCase
    implements UseCase<ShipmentModel, CreateShipmentParams> {
  final ShipmentRepository repository;

  const CreateShipmentUseCase(this.repository);

  @override
  Future<Either<Failure, ShipmentModel>> call(CreateShipmentParams params) {
    return repository.createShipment(
      clientId: params.clientId,
      origin: params.origin,
      destination: params.destination,
      notes: params.notes,
      price: params.price,
      polyline: params.polyline,
      distanceMeters: params.distanceMeters,
      durationSeconds: params.durationSeconds,
    );
  }
}

class CreateShipmentParams {
  final String clientId;
  final ShipmentLocation origin;
  final ShipmentLocation destination;
  final String? notes;
  final double price;
  final String? polyline;
  final int distanceMeters;
  final int durationSeconds;

  const CreateShipmentParams({
    required this.clientId,
    required this.origin,
    required this.destination,
    this.notes,
    this.price = 0.0,
    this.polyline,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
  });
}
