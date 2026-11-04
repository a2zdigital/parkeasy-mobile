import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/profile/state/edit_profile_notifier.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final String _initialName;
  late final String? _initialEmail;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionControllerProvider);
    _initialName = session is SignedIn ? session.user.name ?? '' : '';
    _initialEmail = session is SignedIn ? session.user.email : null;
    _name = TextEditingController(text: _initialName);
    _email = TextEditingController(text: _initialEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (ref.read(editProfileProvider).isSubmitting) return;
    await ref
        .read(editProfileProvider.notifier)
        .save(
          name: _name.text,
          email: _email.text,
          initialName: _initialName,
          initialEmail: _initialEmail,
        );
    if (mounted && ref.read(editProfileProvider).didSave) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(editProfileProvider);
    final failure = state.failure;

    return AppScaffold(
      title: l10n.profileEditTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.xl(),
          AppTextField(
            label: l10n.nameLabel,
            controller: _name,
            enabled: !state.isSubmitting,
            errorText: state.isNameMissing
                ? l10n.nameRequired
                : state.isNameInvalid
                ? l10n.profileEditNameInvalid
                : null,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) =>
                ref.read(editProfileProvider.notifier).clearProblems(),
          ),
          const Gap.lg(),
          AppTextField(
            label: l10n.emailLabel,
            controller: _email,
            enabled: !state.isSubmitting,
            errorText: state.isEmailInvalid
                ? l10n.profileEditEmailInvalid
                : state.isEmailRejected
                ? l10n.profileEditEmailRejected
                : null,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) =>
                ref.read(editProfileProvider.notifier).clearProblems(),
            onSubmitted: state.isSubmitting ? null : (_) => _save(),
          ),
          const Gap.lg(),
          AppBanner(
            tone: StatusTone.info,
            message: l10n.profileEditPhoneNotEditable,
          ),
          if (failure != null) ...[
            const Gap.md(),
            AppBanner(tone: StatusTone.danger, message: l10n.describe(failure)),
            if (failure.requestId case final requestId?) ...[
              const Gap.xs(),
              Text(
                l10n.errorReference(requestId),
                style: context.text.bodySmall.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.profileSaveChanges,
        isLoading: state.isSubmitting,
        onPressed: state.isSubmitting ? null : _save,
      ),
    );
  }
}
