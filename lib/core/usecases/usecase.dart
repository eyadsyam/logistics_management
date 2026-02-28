import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base use case contract for all domain use cases.
/// [Type] is the return type, [Params] is the parameter type.
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Use case that requires no parameters.
class NoParams {
  const NoParams();
}
