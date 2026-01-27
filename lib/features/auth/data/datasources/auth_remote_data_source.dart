import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/core/services/auth_service.dart';
import 'package:ana_ifs_app/core/services/user_initialization_service.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._authService);

  final AuthService _authService;
  final UserInitializationService _userInitializationService =
      UserInitializationService();

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signUp(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid != null) {
      await _userInitializationService.ensureUserInitialized(uid);
    }
    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signIn(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid != null) {
      await _userInitializationService.ensureUserInitialized(uid);
    }
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final credential = await _authService.signInWithGoogle();
    final uid = credential.user?.uid;
    if (uid != null) {
      await _userInitializationService.ensureUserInitialized(uid);
    }
    return credential;
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
