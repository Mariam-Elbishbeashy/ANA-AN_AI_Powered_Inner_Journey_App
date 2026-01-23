import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class SignOut {
  SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.signOut();
  }
}
