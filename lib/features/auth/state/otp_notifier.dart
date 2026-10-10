import 'package:app/core/api/api_exception.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The number of digits in a sign-in code. Fixed by the API.
const int otpLength = 6;

final otpProvider = NotifierProvider.autoDispose
    .family<OtpNotifier, OtpState, CodeSent>(OtpNotifier.new);

class OtpState {
  const OtpState({
    required this.resendAt,
    this.isVerifying = false,
    this.isResending = false,
    this.isIncomplete = false,
    this.wasResent = false,
    this.failure,
  });

  /// When a new code may be requested.
  final DateTime resendAt;
  final bool isVerifying;
  final bool isResending;
  final bool isIncomplete;

  /// True right after a new code was sent, for a one-off confirmation.
  final bool wasResent;
  final ApiException? failure;

  bool get isBusy => isVerifying || isResending;
}

class OtpNotifier extends AutoDisposeFamilyNotifier<OtpState, CodeSent> {
  @override
  OtpState build(CodeSent arg) => OtpState(resendAt: arg.resendAt);

  /// Verifies the code and, on success, starts the session; the router
  /// then leaves the sign-in screens by itself.
  Future<void> verify(String code) async {
    if (state.isBusy) return;

    if (code.length != otpLength) {
      state = OtpState(resendAt: state.resendAt, isIncomplete: true);
      return;
    }

    state = OtpState(resendAt: state.resendAt, isVerifying: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: arg.phone, code: code, deviceName: _deviceName());
      await ref.read(sessionControllerProvider.notifier).start(session);
    } on ApiException catch (failure) {
      state = OtpState(resendAt: state.resendAt, failure: failure);
    }
  }

  Future<void> resend() async {
    if (state.isBusy) return;
    if (ref.read(clockProvider)().isBefore(state.resendAt)) return;

    state = OtpState(resendAt: state.resendAt, isResending: true);
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(arg.phone);
      state = OtpState(
        resendAt: ref
            .read(clockProvider)()
            .add(Duration(seconds: challenge.resendIn)),
        wasResent: true,
      );
    } on ApiException catch (failure) {
      state = OtpState(resendAt: state.resendAt, failure: failure);
    }
  }

  void clearProblems() {
    if (state.isIncomplete || state.failure != null || state.wasResent) {
      state = OtpState(resendAt: state.resendAt);
    }
  }

  /// A label for this device in the user's list of signed-in devices.
  /// Deliberately generic: no model, name or identifier of the phone.
  static String _deviceName() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.android => 'Android phone',
    _ => 'Device',
  };
}
