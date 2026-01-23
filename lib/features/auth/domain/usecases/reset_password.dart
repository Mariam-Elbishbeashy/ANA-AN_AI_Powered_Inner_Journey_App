import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class ResetPassword {
  ResetPassword(this._repository);

  final AuthRepository _repository;

  Future<void> call(String email) {
    return _repository.resetPassword(email);
  }
}
