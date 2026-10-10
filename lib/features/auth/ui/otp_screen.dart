import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/countdown_builder.dart';
import 'package:app/core/widgets/otp_field.dart';
import 'package:app/features/auth/state/otp_notifier.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.sent, super.key});

  final CodeSent sent;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() =>
      ref.read(otpProvider(widget.sent).notifier).verify(_controller.text);

  /// The words for a failure on this screen. Codes about the code itself
  /// are shown under the field; everything else in a banner.
  static String? _fieldError(AppLocalizations l10n, OtpState state) {
    if (state.isIncomplete) return l10n.otpIncomplete(otpLength);
    return switch (state.failure?.code) {
      ApiErrorCode.otpInvalid ||
      ApiErrorCode.validationFailed => l10n.otpInvalid,
      ApiErrorCode.otpExpired => l10n.otpExpired,
      _ => null,
    };
  }

  static String? _bannerError(AppLocalizations l10n, ApiException? failure) {
    if (failure == null) return null;
    return switch (failure.code) {
      ApiErrorCode.otpInvalid ||
      ApiErrorCode.validationFailed ||
      ApiErrorCode.otpExpired => null,
      ApiErrorCode.otpAttemptsExceeded => l10n.otpAttemptsExceeded,
      ApiErrorCode.otpDeliveryFailed => l10n.otpDeliveryFailed,
      _ => l10n.describe(failure),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = otpProvider(widget.sent);
    final state = ref.watch(provider);
    final banner = _bannerError(l10n, state.failure);

    ref.listen(provider, (previous, next) {
      // A wrong code is cleared so the next one can be typed straight away.
      if (next.failure != null && previous?.failure != next.failure) {
        _controller.clear();
      }
    });

    return AppScaffold(
      title: '',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.lg(),
          Text(l10n.otpTitle, style: context.text.h1),
          const Gap.sm(),
          Text(
            l10n.otpBody(otpLength, PhoneNumber.format(widget.sent.phone)),
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          TextAction(
            label: l10n.otpChangeNumber,
            onPressed: state.isBusy ? null : () => context.pop(),
          ),
          const Gap.lg(),
          OtpField(
            label: l10n.otpLabel,
            length: otpLength,
            controller: _controller,
            autofocus: true,
            enabled: !state.isBusy,
            errorText: _fieldError(l10n, state),
            onCompleted: (_) => _verify(),
          ),
          if (banner != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: banner),
          ],
          if (state.wasResent) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.info, message: l10n.otpResent),
          ],
          const Gap.md(),
          CountdownBuilder(
            deadline: state.resendAt,
            builder: (context, secondsLeft) => secondsLeft > 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Text(
                      l10n.otpResendIn(secondsLeft),
                      style: context.text.bodySmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  )
                : TextAction(
                    label: l10n.otpResend,
                    onPressed: state.isBusy
                        ? null
                        : () => ref.read(provider.notifier).resend(),
                  ),
          ),
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.otpVerify,
        isLoading: state.isVerifying,
        onPressed: _verify,
      ),
    );
  }
}
