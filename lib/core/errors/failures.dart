/// Base failure classes for the application.
/// Follows functional error handling with Either pattern (dartz).
abstract class Failure {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Failure originating from server/API calls.
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Failure from Firebase operations.
class FirebaseFailure extends Failure {
  const FirebaseFailure({required super.message, super.code});
}

/// Failure from local cache/storage.
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// Failure from network connectivity issues.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection available',
    super.code,
  });
}

/// Failure from authentication operations.
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Failure for unauthorized access attempts.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Unauthorized access',
    super.code = 403,
  });
}

/// Failure from location services.
class LocationFailure extends Failure {
  const LocationFailure({required super.message, super.code});
}

/// Failure from input validation.
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}
