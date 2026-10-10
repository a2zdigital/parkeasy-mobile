import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/features/profile/state/complete_profile_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asked once, right after a new user's first sign-in.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(completeProfileProvider.notifier)
      .save(name: _name.text, email: _email.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(completeProfileProvider);
    final failure = state.failure;
    void clear(String _) =>
        ref.read(completeProfileProvider.notifier).clearProblems();

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.xxl(),
          Text(l10n.nameTitle, style: context.text.h1),
          const Gap.sm(),
          Text(
            l10n.nameBody,
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Gap.xl(),
          AppTextField(
            label: l10n.nameLabel,
            controller: _name,
            autofocus: true,
            enabled: !state.isSubmitting,
            errorText: state.isNameMissing ? l10n.nameRequired : null,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: clear,
            onSubmitted: (_) => _emailFocus.requestFocus(),
          ),
          const Gap.sm(),
          AppTextField(
            label: l10n.emailLabel,
            controller: _email,
            focusNode: _emailFocus,
            enabled: !state.isSubmitting,
            errorText: state.isEmailInvalid ? l10n.emailInvalid : null,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: clear,
            onSubmitted: (_) => _save(),
          ),
          if (failure != null) ...[
            const Gap.sm(),
            AppBanner(tone: StatusTone.danger, message: l10n.describe(failure)),
          ],
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.nameContinue,
        isLoading: state.isSubmitting,
        onPressed: _save,
      ),
    );
  }
}
