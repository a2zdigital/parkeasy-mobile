import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/owner/data/models/owner_application_input.dart';
import 'package:app/features/owner/data/models/parking_owner.dart';
import 'package:app/features/owner/data/models/verification_status.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ownerApplicationProvider =
    AsyncNotifierProvider.autoDispose<
      OwnerApplicationNotifier,
      OwnerApplicationState
    >(OwnerApplicationNotifier.new);

class OwnerApplicationState {
  const OwnerApplicationState({
    this.application,
    this.isSubmitting = false,
    this.isNameMissing = false,
    this.isPhoneInvalid = false,
    this.failure,
  });

  /// Null when the user has not applied yet.
  final ParkingOwner? application;
  final bool isSubmitting;
  final bool isNameMissing;
  final bool isPhoneInvalid;
  final ApiException? failure;
}

class OwnerApplicationNotifier
    extends AutoDisposeAsyncNotifier<OwnerApplicationState> {
  @override
  Future<OwnerApplicationState> build() async {
    try {
      final application = await ref
          .watch(ownerRepositoryProvider)
          .application();
      if (application.verificationStatus == VerificationStatus.approved) {
        await _refreshRoles();
      }
      return OwnerApplicationState(application: application);
    } on ApiException catch (failure) {
      // "Has not applied" is a normal state, not an error.
      if (failure.code == ApiErrorCode.ownerProfileNotFound) {
        return const OwnerApplicationState();
      }
      rethrow;
    }
  }

  Future<void> apply({
    required String businessName,
    required String contactPhone,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitting) return;

    final name = businessName.trim();
    final phone = PhoneNumber.toE164(contactPhone);
    if (name.isEmpty || phone == null) {
      state = AsyncData(
        OwnerApplicationState(
          isNameMissing: name.isEmpty,
          isPhoneInvalid: phone == null,
        ),
      );
      return;
    }

    state = const AsyncData(OwnerApplicationState(isSubmitting: true));
    try {
      final application = await ref
          .read(ownerRepositoryProvider)
          .apply(
            OwnerApplicationInput(businessName: name, contactPhone: phone),
          );
      state = AsyncData(OwnerApplicationState(application: application));
    } on ApiException catch (failure) {
      if (failure.code == ApiErrorCode.ownerApplicationExists) {
        // Applied from another device: show that application.
        ref.invalidateSelf();
        return;
      }
      final fields = failure.code == ApiErrorCode.validationFailed
          ? failure.fieldErrors
          : const <String, List<String>>{};
      state = AsyncData(
        OwnerApplicationState(
          isNameMissing: fields.containsKey('business_name'),
          isPhoneInvalid: fields.containsKey('contact_phone'),
          failure: fields.isEmpty ? failure : null,
        ),
      );
    }
  }

  void clearProblems() {
    final current = state.valueOrNull;
    if (current == null || current.application != null) return;
    if (current.isNameMissing ||
        current.isPhoneInvalid ||
        current.failure != null) {
      state = const AsyncData(OwnerApplicationState());
    }
  }

  /// Approval adds the owner role on the server; fetch the user again so
  /// the rest of the app knows.
  Future<void> _refreshRoles() async {
    try {
      final user = await ref.read(authRepositoryProvider).currentUser();
      ref.read(sessionControllerProvider.notifier).updateUser(user);
    } on ApiException {
      // The role is only used for display; the API enforces access.
    }
  }
}
