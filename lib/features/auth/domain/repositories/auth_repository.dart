import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../models/user_model.dart';

/// Repository contract for authentication operations.
/// Implemented in data layer, used by domain use cases.
abstract class AuthRepository {
  /// Sign in with email and password.
  Future<Either<Failure, UserModel>> signIn({
    required String email,
    required String password,
  });

  /// Register a new user with role assignment.
  Future<Either<Failure, UserModel>> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  });

  /// Sign out current user.
  Future<Either<Failure, void>> signOut();

  /// Get the currently authenticated user.
  Future<Either<Failure, UserModel?>> getCurrentUser();

  /// Stream the authentication state changes.
  Stream<UserModel?> get authStateChanges;

  /// Update user profile.
  Future<Either<Failure, UserModel>> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? profileImageUrl,
  });
}
