import 'package:ana_ifs_app/features/auth/domain/repositories/auth_repository.dart';

class ChangePassword {
  ChangePassword(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
