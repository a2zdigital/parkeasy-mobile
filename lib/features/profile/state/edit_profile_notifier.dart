import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/profile/data/profile_repository.dart';
import 'package:app/features/profile/state/profile_validation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final editProfileProvider =
    NotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>(
      EditProfileNotifier.new,
    );

class EditProfileState {
  const EditProfileState({
    this.isSubmitting = false,
    this.isNameMissing = false,
    this.isNameInvalid = false,
    this.isEmailInvalid = false,
    this.isEmailRejected = false,
    this.didSave = false,
    this.failure,
  });

  final bool isSubmitting;
  final bool isNameMissing;
  final bool isNameInvalid;
  final bool isEmailInvalid;
  final bool isEmailRejected;
  final bool didSave;
  final ApiException? failure;
}

class EditProfileNotifier extends AutoDisposeNotifier<EditProfileState> {
  @override
  EditProfileState build() => const EditProfileState();

  Future<void> save({
    required String name,
    required String email,
    required String initialName,
    required String? initialEmail,
  }) async {
    if (state.isSubmitting) return;

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final nameLength = trimmedName.runes.length;
    final emailInvalid = !isOptionalProfileEmailValid(trimmedEmail);
    final nameChanged = trimmedName != initialName.trim();
    final emailChanged = trimmedEmail != (initialEmail ?? '').trim();
    if (nameLength < 2 || nameLength > 120 || emailInvalid) {
      state = EditProfileState(
        isNameMissing: trimmedName.isEmpty,
        isNameInvalid: trimmedName.isNotEmpty,
        isEmailInvalid: emailInvalid,
      );
      return;
    }
    if (!nameChanged && !emailChanged) {
      state = const EditProfileState(didSave: true);
      return;
    }

    state = const EditProfileState(isSubmitting: true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .update(
            name: nameChanged ? trimmedName : null,
            email: emailChanged && trimmedEmail.isNotEmpty
                ? trimmedEmail
                : null,
            includeEmail: emailChanged,
          );
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      state = const EditProfileState(didSave: true);
    } on ApiException catch (failure) {
      final fields = failure.code == ApiErrorCode.validationFailed
          ? failure.fieldErrors
          : const <String, List<String>>{};
      state = EditProfileState(
        isNameInvalid: fields.containsKey('name'),
        isEmailRejected: fields.containsKey('email'),
        failure: fields.isEmpty ? failure : null,
      );
    }
  }

  void clearProblems() {
    if (state.isNameMissing ||
        state.isNameInvalid ||
        state.isEmailInvalid ||
        state.isEmailRejected ||
        state.failure != null) {
      state = const EditProfileState();
    }
  }
}
