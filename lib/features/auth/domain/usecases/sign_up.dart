import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class SignUp {
  SignUp(this._repository);

  final AuthRepository _repository;

  Future<UserCredential> call({
    required String email,
    required String password,
  }) {
    return _repository.signUp(email: email, password: password);
  }
}
