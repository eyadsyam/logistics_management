import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firebase implementation of AuthRepository.
/// Handles authentication and user profile management via Firebase Auth + Firestore.
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Logger _logger;

  AuthRepositoryImpl({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required Logger logger,
  }) : _auth = auth,
       _firestore = firestore,
       _logger = logger;

  @override
  Future<Either<Failure, UserModel>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Left(AuthFailure(message: 'Sign in failed'));
      }

      // Fetch user profile from Firestore
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        return const Left(AuthFailure(message: 'User profile not found'));
      }

      final userData = userDoc.data()!;
      userData['id'] = credential.user!.uid;

      final user = UserModel.fromJson(userData);
      _logger.i('User signed in: ${user.email} (${user.role})');
      return Right(user);
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign in error: ${e.message}');
      return Left(AuthFailure(message: _mapAuthError(e.code)));
    } catch (e) {
      _logger.e('Unexpected sign in error: $e');
      return Left(AuthFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserModel>> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Left(AuthFailure(message: 'Registration failed'));
      }

      final uid = credential.user!.uid;
      final now = DateTime.now();

      // Build user model
      final user = UserModel(
        id: uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Store in Firestore users collection
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(user.toJson());

      // If registering as driver, also create driver profile
      if (role == AppConstants.roleDriver) {
        await _firestore
            .collection(AppConstants.driversCollection)
            .doc(uid)
            .set({
              'id': uid,
              'name': name,
              'phone': phone,
              'email': email,
              'isOnline': false,
              'currentLocation': null,
              'lastUpdated': FieldValue.serverTimestamp(),
              'currentShipmentId': null,
              'totalTrips': 0,
              'rating': 0.0,
            });
      }

      _logger.i('User registered: $email ($role)');
      return Right(user);
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign up error: ${e.message}');
      return Left(AuthFailure(message: _mapAuthError(e.code)));
    } catch (e) {
      _logger.e('Unexpected sign up error: $e');
      return Left(AuthFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _auth.signOut();
      _logger.i('User signed out');
      return const Right(null);
    } catch (e) {
      _logger.e('Sign out error: $e');
      return Left(AuthFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserModel?>> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return const Right(null);
      }

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        return const Right(null);
      }

      final userData = userDoc.data()!;
      userData['id'] = firebaseUser.uid;

      return Right(UserModel.fromJson(userData));
    } catch (e) {
      _logger.e('Get current user error: $e');
      return Left(AuthFailure(message: e.toString()));
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      try {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(firebaseUser.uid)
            .get();

        if (!userDoc.exists) return null;

        final userData = userDoc.data()!;
        userData['id'] = firebaseUser.uid;
        return UserModel.fromJson(userData);
      } catch (e) {
        _logger.e('Auth state change error: $e');
        return null;
      }
    });
  }

  @override
  Future<Either<Failure, UserModel>> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (profileImageUrl != null) {
        updates['profileImageUrl'] = profileImageUrl;
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(updates);

      // Fetch updated profile
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      final userData = userDoc.data()!;
      userData['id'] = userId;

      return Right(UserModel.fromJson(userData));
    } catch (e) {
      _logger.e('Update profile error: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Maps Firebase Auth error codes to user-friendly messages.
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication error: $code';
    }
  }
}
