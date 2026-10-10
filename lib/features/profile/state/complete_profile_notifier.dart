import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completeProfileProvider =
    NotifierProvider.autoDispose<CompleteProfileNotifier, CompleteProfileState>(
      CompleteProfileNotifier.new,
    );

class CompleteProfileState {
  const CompleteProfileState({
    this.isSubmitting = false,
    this.isNameMissing = false,
    this.isEmailInvalid = false,
    this.failure,
  });

  final bool isSubmitting;
  final bool isNameMissing;
  final bool isEmailInvalid;

  /// A failure that is not about a single field.
  final ApiException? failure;
}

class CompleteProfileNotifier
    extends AutoDisposeNotifier<CompleteProfileState> {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  CompleteProfileState build() => const CompleteProfileState();

  /// Saves the name (and email, when given). On success the session's
  /// user is replaced and the router moves on.
  Future<void> save({required String name, required String email}) async {
    if (state.isSubmitting) return;

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final nameMissing = trimmedName.isEmpty;
    final emailInvalid =
        trimmedEmail.isNotEmpty && !_email.hasMatch(trimmedEmail);
    if (nameMissing || emailInvalid) {
      state = CompleteProfileState(
        isNameMissing: nameMissing,
        isEmailInvalid: emailInvalid,
      );
      return;
    }

    state = const CompleteProfileState(isSubmitting: true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .update(
            name: trimmedName,
            email: trimmedEmail.isEmpty ? null : trimmedEmail,
          );
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      state = const CompleteProfileState();
    } on ApiException catch (failure) {
      // The API's own validation: show it on the fields it names.
      final fields = failure.code == ApiErrorCode.validationFailed
          ? failure.fieldErrors
          : const <String, List<String>>{};
      state = CompleteProfileState(
        isNameMissing: fields.containsKey('name'),
        isEmailInvalid: fields.containsKey('email'),
        failure: fields.isEmpty ? failure : null,
      );
    }
  }

  void clearProblems() {
    if (state.isNameMissing || state.isEmailInvalid || state.failure != null) {
      state = const CompleteProfileState();
    }
  }
}
