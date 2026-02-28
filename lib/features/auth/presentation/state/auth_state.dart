import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/models/user_model.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

part 'auth_state.freezed.dart';

/// Authentication state using Freezed sealed unions.
@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState.initial() = _AuthInitial;
  const factory AuthState.loading() = _AuthLoading;
  const factory AuthState.authenticated(UserModel user) = _AuthAuthenticated;
  const factory AuthState.unauthenticated() = _AuthUnauthenticated;
  const factory AuthState.error(String message) = _AuthError;
}

/// Auth state notifier managing login/signup flows.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState.initial()) {
    _checkAuthState();
  }

  /// Check initial auth state on app launch.
  Future<void> _checkAuthState() async {
    final result = await _ref.read(authRepositoryProvider).getCurrentUser();
    result.fold((failure) => state = const AuthState.unauthenticated(), (user) {
      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    });
  }

  /// Sign in with email and password.
  Future<void> signIn({required String email, required String password}) async {
    state = const AuthState.loading();

    final result = await _ref
        .read(signInUseCaseProvider)
        .call(SignInParams(email: email, password: password));

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      _ref.read(currentUserProvider.notifier).state = user;
      state = AuthState.authenticated(user);
    });
  }

  /// Register new user.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    state = const AuthState.loading();

    final result = await _ref
        .read(signUpUseCaseProvider)
        .call(
          SignUpParams(
            name: name,
            email: email,
            password: password,
            phone: phone,
            role: role,
          ),
        );

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      _ref.read(currentUserProvider.notifier).state = user;
      state = AuthState.authenticated(user);
    });
  }

  /// Sign out.
  Future<void> signOut() async {
    await _ref.read(signOutUseCaseProvider).call(const NoParams());
    _ref.read(currentUserProvider.notifier).state = null;
    state = const AuthState.unauthenticated();
  }
}

/// Auth notifier provider.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref);
});
