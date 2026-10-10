import 'package:app/app/routes.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/phone_sign_in_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

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

  void _submit() =>
      ref.read(phoneSignInProvider.notifier).submit(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(phoneSignInProvider);
    final failure = state.failure;

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
          Text(l10n.phoneTitle, style: context.text.h1),
          const Gap.sm(),
          Text(
            l10n.phoneBody,
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
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
          if (failure != null) ...[
            const Gap.md(),
            AppBanner(tone: StatusTone.danger, message: l10n.describe(failure)),
          ],
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.phoneSendCode,
        isLoading: state.isSubmitting,
        onPressed: _submit,
      ),
    );
  }
}
