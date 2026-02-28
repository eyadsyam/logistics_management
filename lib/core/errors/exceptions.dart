/// Custom exception classes that get caught and mapped to Failures.
class ServerException implements Exception {
  final String message;
  final int? code;
  const ServerException({required this.message, this.code});
}

class CacheException implements Exception {
  final String message;
  const CacheException({this.message = 'Cache operation failed'});
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'No internet connection'});
}

class AuthException implements Exception {
  final String message;
  final int? code;
  const AuthException({required this.message, this.code});
}

class LocationException implements Exception {
  final String message;
  const LocationException({required this.message});
}
