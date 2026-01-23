import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _remoteDataSource.signUp(email: email, password: password);
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _remoteDataSource.signIn(email: email, password: password);
  }

  @override
  Future<UserCredential> signInWithGoogle() {
    return _remoteDataSource.signInWithGoogle();
  }

  @override
  Future<void> resetPassword(String email) {
    return _remoteDataSource.resetPassword(email);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> signOut() {
    return _remoteDataSource.signOut();
  }
}
