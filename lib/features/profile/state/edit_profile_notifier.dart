import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/profile/data/profile_repository.dart';
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
    this.didSave = false,
    this.failure,
  });

  final bool isSubmitting;
  final bool isNameMissing;
  final bool isNameInvalid;
  final bool didSave;
  final ApiException? failure;
}

class EditProfileNotifier extends AutoDisposeNotifier<EditProfileState> {
  @override
  EditProfileState build() => const EditProfileState();

  Future<void> save({required String name}) async {
    if (state.isSubmitting) return;

    final trimmedName = name.trim();
    final nameLength = trimmedName.runes.length;
    if (nameLength < 2 || nameLength > 120) {
      state = EditProfileState(
        isNameMissing: trimmedName.isEmpty,
        isNameInvalid: trimmedName.isNotEmpty,
      );
      return;
    }

    state = const EditProfileState(isSubmitting: true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .update(name: trimmedName);
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      state = const EditProfileState(didSave: true);
    } on ApiException catch (failure) {
      final fields = failure.code == ApiErrorCode.validationFailed
          ? failure.fieldErrors
          : const <String, List<String>>{};
      state = EditProfileState(
        isNameInvalid: fields.containsKey('name'),
        failure: fields.isEmpty ? failure : null,
      );
    }
  }

  void clearProblems() {
    if (state.isNameMissing || state.isNameInvalid || state.failure != null) {
      state = const EditProfileState();
    }
  }
}
