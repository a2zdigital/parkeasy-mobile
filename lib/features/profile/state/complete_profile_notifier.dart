import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/state/registration_role.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/profile/data/profile_repository.dart';
import 'package:app/features/profile/state/profile_validation.dart';
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
  @override
  CompleteProfileState build() => const CompleteProfileState();

  /// Saves the name (and email, when given). On success the session's
  /// user is replaced and the router moves on.
  Future<void> save({required String name, required String email}) async {
    if (state.isSubmitting) return;

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final nameMissing = trimmedName.isEmpty;
    final emailInvalid = !isOptionalProfileEmailValid(trimmedEmail);
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
            includeEmail: trimmedEmail.isNotEmpty,
          );
      final session = ref.read(sessionControllerProvider);
      if (session is SignedIn &&
          session.registrationRole == RegistrationRole.owner) {
        ref.read(sessionControllerProvider.notifier).updateUser(user);
      } else if (session is SignedIn && session.registrationRole != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .finishRegistration(user: user);
      } else {
        ref.read(sessionControllerProvider.notifier).updateUser(user);
      }
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
