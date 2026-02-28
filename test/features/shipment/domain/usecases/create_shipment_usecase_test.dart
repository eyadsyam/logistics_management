import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:logistics_management/core/errors/failures.dart';
import 'package:logistics_management/features/shipment/domain/models/shipment_model.dart';
import 'package:logistics_management/features/shipment/domain/repositories/shipment_repository.dart';
import 'package:logistics_management/features/shipment/domain/usecases/create_shipment_usecase.dart';

@GenerateMocks([ShipmentRepository])
import 'create_shipment_usecase_test.mocks.dart';

void main() {
  late CreateShipmentUseCase useCase;
  late MockShipmentRepository mockRepository;

  setUp(() {
    mockRepository = MockShipmentRepository();
    useCase = CreateShipmentUseCase(mockRepository);
  });

  final testOrigin = const ShipmentLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    address: '123 Origin Street, Cairo',
  );

  final testDestination = const ShipmentLocation(
    latitude: 30.0626,
    longitude: 31.2497,
    address: '456 Destination Ave, Cairo',
  );

  final testShipment = ShipmentModel(
    id: 'shipment-123',
    clientId: 'client-123',
    status: 'pending',
    origin: testOrigin,
    destination: testDestination,
    createdAt: DateTime(2024, 1, 1),
  );

  group('CreateShipmentUseCase', () {
    test('should create a shipment and return ShipmentModel', () async {
      // Arrange
      when(
        mockRepository.createShipment(
          clientId: anyNamed('clientId'),
          origin: anyNamed('origin'),
          destination: anyNamed('destination'),
          notes: anyNamed('notes'),
        ),
      ).thenAnswer((_) async => Right(testShipment));

      // Act
      final result = await useCase(
        CreateShipmentParams(
          clientId: 'client-123',
          origin: testOrigin,
          destination: testDestination,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold((l) => fail('Should not return failure'), (r) {
        expect(r.id, 'shipment-123');
        expect(r.status, 'pending');
        expect(r.clientId, 'client-123');
      });

      verify(
        mockRepository.createShipment(
          clientId: 'client-123',
          origin: testOrigin,
          destination: testDestination,
          notes: null,
        ),
      ).called(1);
    });

    test('should return ServerFailure when creation fails', () async {
      // Arrange
      const failure = ServerFailure(message: 'Network error');
      when(
        mockRepository.createShipment(
          clientId: anyNamed('clientId'),
          origin: anyNamed('origin'),
          destination: anyNamed('destination'),
          notes: anyNamed('notes'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        CreateShipmentParams(
          clientId: 'client-123',
          origin: testOrigin,
          destination: testDestination,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (l) => expect(l.message, 'Network error'),
        (r) => fail('Should not return success'),
      );
    });
  });
}
