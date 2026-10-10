import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final phoneSignInProvider =
    NotifierProvider.autoDispose<PhoneSignInNotifier, PhoneSignInState>(
      PhoneSignInNotifier.new,
    );

/// A code was sent: where, and when another may be requested.
class CodeSent {
  const CodeSent({required this.phone, required this.resendAt});

  final String phone;
  final DateTime resendAt;
}

class PhoneSignInState {
  const PhoneSignInState({
    this.isSubmitting = false,
    this.isPhoneInvalid = false,
    this.failure,
    this.sent,
  });

  final bool isSubmitting;
  final bool isPhoneInvalid;
  final ApiException? failure;

  /// Set once when the code was sent; the screen moves on.
  final CodeSent? sent;
}

class PhoneSignInNotifier extends AutoDisposeNotifier<PhoneSignInState> {
  @override
  PhoneSignInState build() => const PhoneSignInState();

  Future<void> submit(String input) async {
    if (state.isSubmitting) return;

    final phone = PhoneNumber.toE164(input);
    if (phone == null) {
      state = const PhoneSignInState(isPhoneInvalid: true);
      return;
    }

    state = const PhoneSignInState(isSubmitting: true);
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone);
      state = PhoneSignInState(
        sent: CodeSent(
          phone: phone,
          resendAt: ref
              .read(clockProvider)()
              .add(Duration(seconds: challenge.resendIn)),
        ),
      );
    } on ApiException catch (failure) {
      state = PhoneSignInState(failure: failure);
    }
  }

  /// The user edited the field: stop showing the last problem.
  void clearProblems() {
    if (state.isPhoneInvalid || state.failure != null) {
      state = const PhoneSignInState();
    }
  }
}
