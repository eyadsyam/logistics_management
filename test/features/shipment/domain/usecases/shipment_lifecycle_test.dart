import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:logistics_management/core/errors/failures.dart';
import 'package:logistics_management/features/shipment/domain/models/shipment_model.dart';
import 'package:logistics_management/features/shipment/domain/repositories/shipment_repository.dart';
import 'package:logistics_management/features/shipment/domain/usecases/accept_shipment_usecase.dart';
import 'package:logistics_management/features/shipment/domain/usecases/shipment_lifecycle_usecases.dart';

@GenerateMocks([ShipmentRepository])
import 'shipment_lifecycle_test.mocks.dart';

void main() {
  late MockShipmentRepository mockRepository;

  setUp(() {
    mockRepository = MockShipmentRepository();
  });

  final testShipment = ShipmentModel(
    id: 'shipment-123',
    clientId: 'client-123',
    driverId: 'driver-123',
    status: 'accepted',
    origin: const ShipmentLocation(
      latitude: 30.0444,
      longitude: 31.2357,
      address: 'Origin',
    ),
    destination: const ShipmentLocation(
      latitude: 30.0626,
      longitude: 31.2497,
      address: 'Destination',
    ),
  );

  group('AcceptShipmentUseCase', () {
    late AcceptShipmentUseCase useCase;

    setUp(() {
      useCase = AcceptShipmentUseCase(mockRepository);
    });

    test('should accept a pending shipment', () async {
      when(
        mockRepository.acceptShipment(
          shipmentId: anyNamed('shipmentId'),
          driverId: anyNamed('driverId'),
          driverName: anyNamed('driverName'),
        ),
      ).thenAnswer((_) async => Right(testShipment));

      final result = await useCase(
        const AcceptShipmentParams(
          shipmentId: 'shipment-123',
          driverId: 'driver-123',
          driverName: 'Test Driver',
        ),
      );

      expect(result.isRight(), true);
    });

    test('should return failure if shipment already taken', () async {
      when(
        mockRepository.acceptShipment(
          shipmentId: anyNamed('shipmentId'),
          driverId: anyNamed('driverId'),
          driverName: anyNamed('driverName'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          ServerFailure(message: 'Shipment is no longer available'),
        ),
      );

      final result = await useCase(
        const AcceptShipmentParams(
          shipmentId: 'shipment-123',
          driverId: 'driver-456',
          driverName: 'Other Driver',
        ),
      );

      expect(result.isLeft(), true);
    });
  });

  group('StartShipmentUseCase', () {
    late StartShipmentUseCase useCase;

    setUp(() {
      useCase = StartShipmentUseCase(mockRepository);
    });

    test('should start an accepted shipment', () async {
      final startedShipment = testShipment.copyWith(status: 'in_progress');

      when(
        mockRepository.startShipment(any),
      ).thenAnswer((_) async => Right(startedShipment));

      final result = await useCase('shipment-123');

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should succeed'),
        (r) => expect(r.status, 'in_progress'),
      );
    });
  });

  group('CompleteShipmentUseCase', () {
    late CompleteShipmentUseCase useCase;

    setUp(() {
      useCase = CompleteShipmentUseCase(mockRepository);
    });

    test('should complete an in-progress shipment', () async {
      final completedShipment = testShipment.copyWith(status: 'completed');

      when(
        mockRepository.completeShipment(any),
      ).thenAnswer((_) async => Right(completedShipment));

      final result = await useCase('shipment-123');

      expect(result.isRight(), true);
      result.fold(
        (l) => fail('Should succeed'),
        (r) => expect(r.status, 'completed'),
      );
    });
  });

  group('CancelShipmentUseCase', () {
    late CancelShipmentUseCase useCase;

    setUp(() {
      useCase = CancelShipmentUseCase(mockRepository);
    });

    test('should cancel a pending shipment', () async {
      when(
        mockRepository.cancelShipment(any),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('shipment-123');

      expect(result.isRight(), true);
    });

    test('should fail to cancel an in-progress shipment', () async {
      when(mockRepository.cancelShipment(any)).thenAnswer(
        (_) async => const Left(
          ServerFailure(message: 'Cannot cancel an in-progress shipment'),
        ),
      );

      final result = await useCase('shipment-123');

      expect(result.isLeft(), true);
    });
  });
}
