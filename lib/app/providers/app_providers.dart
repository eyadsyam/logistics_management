import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../core/network/network_info.dart';
import '../../core/services/location_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/domain/usecases/sign_up_usecase.dart';
import '../../features/driver/data/repositories/driver_repository_impl.dart';
import '../../features/driver/domain/repositories/driver_repository.dart';
import '../../features/map/data/services/mapbox_service.dart';
import '../../features/shipment/data/repositories/shipment_repository_impl.dart';
import '../../features/shipment/domain/repositories/shipment_repository.dart';
import '../../features/shipment/domain/usecases/accept_shipment_usecase.dart';
import '../../features/shipment/domain/usecases/create_shipment_usecase.dart';
import '../../features/shipment/domain/usecases/shipment_lifecycle_usecases.dart';

// ════════════════════════════════════════════════════════════
// CORE PROVIDERS
// ════════════════════════════════════════════════════════════

/// Logger provider
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
});

/// Firebase Auth provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firestore provider with offline persistence enabled
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  return firestore;
});

/// Dio HTTP client provider
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

/// Network info provider
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl(connectivity: Connectivity());
});

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(logger: ref.read(loggerProvider));
});

/// Mapbox service provider
final mapboxServiceProvider = Provider<MapboxService>((ref) {
  return MapboxService(
    dio: ref.read(dioProvider),
    logger: ref.read(loggerProvider),
  );
});

// ════════════════════════════════════════════════════════════
// REPOSITORY PROVIDERS
// ════════════════════════════════════════════════════════════

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    auth: ref.read(firebaseAuthProvider),
    firestore: ref.read(firestoreProvider),
    logger: ref.read(loggerProvider),
  );
});

/// Shipment repository provider
final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  return ShipmentRepositoryImpl(
    firestore: ref.read(firestoreProvider),
    logger: ref.read(loggerProvider),
  );
});

/// Driver repository provider
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepositoryImpl(
    firestore: ref.read(firestoreProvider),
    logger: ref.read(loggerProvider),
  );
});

// ════════════════════════════════════════════════════════════
// USE CASE PROVIDERS
// ════════════════════════════════════════════════════════════

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.read(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.read(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.read(authRepositoryProvider));
});

final createShipmentUseCaseProvider = Provider<CreateShipmentUseCase>((ref) {
  return CreateShipmentUseCase(ref.read(shipmentRepositoryProvider));
});

final acceptShipmentUseCaseProvider = Provider<AcceptShipmentUseCase>((ref) {
  return AcceptShipmentUseCase(ref.read(shipmentRepositoryProvider));
});

final startShipmentUseCaseProvider = Provider<StartShipmentUseCase>((ref) {
  return StartShipmentUseCase(ref.read(shipmentRepositoryProvider));
});

final completeShipmentUseCaseProvider = Provider<CompleteShipmentUseCase>((
  ref,
) {
  return CompleteShipmentUseCase(ref.read(shipmentRepositoryProvider));
});

final cancelShipmentUseCaseProvider = Provider<CancelShipmentUseCase>((ref) {
  return CancelShipmentUseCase(ref.read(shipmentRepositoryProvider));
});

// ════════════════════════════════════════════════════════════
// AUTH STATE PROVIDERS
// ════════════════════════════════════════════════════════════

/// Streams the current authenticated user across the app.
final authStateProvider = StreamProvider<UserModel?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});

/// Stores the current user after sign-in for synchronous access.
final currentUserProvider = StateProvider<UserModel?>((ref) {
  return null;
});
