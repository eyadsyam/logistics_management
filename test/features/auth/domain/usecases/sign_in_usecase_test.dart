import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:logistics_management/core/errors/failures.dart';
import 'package:logistics_management/features/auth/domain/models/user_model.dart';
import 'package:logistics_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:logistics_management/features/auth/domain/usecases/sign_in_usecase.dart';

@GenerateMocks([AuthRepository])
import 'sign_in_usecase_test.mocks.dart';

void main() {
  late SignInUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignInUseCase(mockRepository);
  });

  final testUser = UserModel(
    id: 'user-123',
    name: 'Test User',
    email: 'test@example.com',
    phone: '+1234567890',
    role: 'client',
    createdAt: DateTime(2024, 1, 1),
  );

  group('SignInUseCase', () {
    test('should return UserModel on successful sign in', () async {
      // Arrange
      when(
        mockRepository.signIn(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) async => Right(testUser));

      // Act
      final result = await useCase(
        const SignInParams(email: 'test@example.com', password: 'password123'),
      );

      // Assert
      expect(result, Right(testUser));
      verify(
        mockRepository.signIn(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return AuthFailure when credentials are invalid', () async {
      // Arrange
      const failure = AuthFailure(message: 'Incorrect password');
      when(
        mockRepository.signIn(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignInParams(email: 'test@example.com', password: 'wrong'),
      );

      // Assert
      expect(result, const Left(failure));
    });

    test('should return AuthFailure when user not found', () async {
      // Arrange
      const failure = AuthFailure(message: 'No account found with this email');
      when(
        mockRepository.signIn(
          email: anyNamed('email'),
          password: anyNamed('password'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(
        const SignInParams(
          email: 'nonexistent@example.com',
          password: 'password123',
        ),
      );

      // Assert
      expect(result, const Left(failure));
    });
  });
}
