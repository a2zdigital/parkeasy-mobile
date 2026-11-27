import 'package:app/app/routes.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/countdown_builder.dart';
import 'package:app/core/widgets/screen_intro.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/features/auth/state/registration_role.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({this.registrationRole, super.key});

  final RegistrationRole? registrationRole;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(phoneSignInProvider.notifier)
      .submit(_controller.text, registrationRole: widget.registrationRole);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(phoneSignInProvider);
    final failure = state.failure;
    final retryAt = state.retryAt;

    ref.listen(phoneSignInProvider, (previous, next) {
      final sent = next.sent;
      if (sent != null && previous?.sent != sent) {
        context.push(Routes.code, extra: sent);
      }
    });

    return AppScaffold(
      title: '',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.lg(),
          ScreenIntro(
            icon: Icons.smartphone_outlined,
            title: l10n.phoneTitle,
            body: l10n.phoneBody,
          ),
          const Gap.xl(),
          AppTextField(
            label: l10n.phoneLabel,
            controller: _controller,
            autofocus: true,
            enabled: !state.isSubmitting,
            prefixText: '${PhoneNumber.countryCode} ',
            helperText: l10n.phoneHelper,
            errorText: state.isPhoneInvalid ? l10n.phoneInvalid : null,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PhoneNumber.nationalLength),
            ],
            onChanged: (_) =>
                ref.read(phoneSignInProvider.notifier).clearProblems(),
            onSubmitted: (_) => _submit(),
          ),
          const Gap.lg(),
          PrivacyNote(text: l10n.phonePrivacy),
          if (failure != null) ...[
            const Gap.md(),
            if (retryAt != null)
              CountdownBuilder(
                deadline: retryAt,
                builder: (context, left) => AppBanner(
                  tone: left > 0 ? StatusTone.danger : StatusTone.info,
                  message: left > 0
                      ? l10n.phoneRetryIn(formatWait(left))
                      : l10n.phoneRetryNow,
                ),
              )
            else
              AppBanner(
                tone: StatusTone.danger,
                message: l10n.describe(failure),
              ),
          ],
        ],
      ),
      // While a refusal's wait runs, the button counts down and sends nothing.
      bottom: retryAt == null
          ? PrimaryButton(
              label: l10n.phoneSendCode,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            )
          : CountdownBuilder(
              deadline: retryAt,
              builder: (context, left) => PrimaryButton(
                label: left > 0
                    ? l10n.phoneSendCodeIn(formatWait(left))
                    : l10n.phoneSendCode,
                isLoading: state.isSubmitting,
                onPressed: left > 0 ? null : _submit,
              ),
            ),
    );
  }
}

/// A wait as "45 s" under a minute, otherwise "m:ss".
String formatWait(int seconds) {
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}
