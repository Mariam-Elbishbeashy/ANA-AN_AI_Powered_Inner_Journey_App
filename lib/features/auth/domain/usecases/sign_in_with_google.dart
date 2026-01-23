import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class SignInWithGoogle {
  SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<UserCredential> call() {
    return _repository.signInWithGoogle();
  }
}
