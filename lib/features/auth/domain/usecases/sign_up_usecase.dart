import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Register a new user with role assignment.
class SignUpUseCase implements UseCase<UserModel, SignUpParams> {
  final AuthRepository repository;

  const SignUpUseCase(this.repository);

  @override
  Future<Either<Failure, UserModel>> call(SignUpParams params) {
    return repository.signUp(
      name: params.name,
      email: params.email,
      password: params.password,
      phone: params.phone,
      role: params.role,
    );
  }
}

class SignUpParams {
  final String name;
  final String email;
  final String password;
  final String phone;
  final String role;

  const SignUpParams({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.role,
  });
}
