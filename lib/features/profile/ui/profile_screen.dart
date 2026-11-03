import 'package:app/app/routes.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.signOutConfirmTitle,
      body: l10n.signOutConfirmBody,
      confirmLabel: l10n.profileSignOut,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    if (session is! SignedIn) {
      // The router is about to leave this screen.
      return const SizedBox.shrink();
    }
    final user = session.user;

    return AppScaffold(
      title: l10n.profileTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.xl(),
          Row(
            children: [
              Expanded(
                child: Text(
                  user.name ?? l10n.profileNameMissing,
                  style: context.text.h2,
                ),
              ),
              TextAction(
                label: l10n.profileEdit,
                onPressed: () async {
                  final saved = await context.push<bool>(Routes.profileEdit);
                  if (saved == true && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
                  }
                },
              ),
            ],
          ),
          const Gap.lg(),
          _Details(
            rows: [
              (l10n.profilePhone, PhoneNumber.format(user.phone)),
              (l10n.profileEmail, user.email ?? l10n.profileEmailMissing),
            ],
          ),
          const Gap.md(),
          Semantics(
            button: true,
            child: AppCard(
              onTap: () => context.push(
                user.isOwner ? Routes.ownerBookings : Routes.owner,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.storefront_outlined,
                      size: AppSize.icon,
                      color: context.colors.primary,
                    ),
                  ),
                  const Gap.md(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.profileOwnerArea, style: context.text.body),
                        Text(
                          l10n.profileOwnerAreaHint,
                          style: context.text.bodySmall.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap.xl(),
          TextAction(
            label: l10n.profileSignOut,
            isDestructive: true,
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.rows});

  final List<(String label, String value)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          children: [
            for (final (index, (label, value)) in rows.indexed) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Divider(),
                ),
              MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.text.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Gap.lg(),
                    Expanded(
                      child: Text(
                        value,
                        style: context.text.body,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
