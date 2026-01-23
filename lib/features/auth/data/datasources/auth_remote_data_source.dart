import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/core/services/auth_service.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._authService);

  final AuthService _authService;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _authService.signUp(email: email, password: password);
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _authService.signIn(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() {
    return _authService.signInWithGoogle();
  }

  Future<void> resetPassword(String email) {
    return _authService.resetPassword(email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> signOut() {
    return _authService.signOut();
  }
}
