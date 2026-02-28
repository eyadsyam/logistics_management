import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Sign in use case. Takes email/password credentials.
class SignInUseCase implements UseCase<UserModel, SignInParams> {
  final AuthRepository repository;

  const SignInUseCase(this.repository);

  @override
  Future<Either<Failure, UserModel>> call(SignInParams params) {
    return repository.signIn(email: params.email, password: params.password);
  }
}

class SignInParams {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});
}
