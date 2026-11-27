import 'package:app/app/routes.dart';
import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_list_row.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/confirm_dialog.dart';
import 'package:app/features/auth/state/phone_number.dart';
import 'package:app/features/auth/state/session_controller.dart';
import 'package:app/features/auth/state/session_state.dart';
import 'package:app/features/gate/data/gate_repository.dart';
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
    final hasGate =
        ref.watch(gateFacilitiesProvider).valueOrNull?.isNotEmpty ?? false;

    Future<void> editProfile() async {
      final saved = await context.push<bool>(
        user.isOwner ? Routes.ownerProfileEdit : Routes.profileEdit,
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      }
    }

    return AppScaffold(
      title: l10n.profileTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.lg(),
          FadeSlideIn(
            child: _Header(
              name: user.name,
              rows: [
                (
                  Icons.phone_outlined,
                  l10n.profilePhone,
                  PhoneNumber.format(user.phone),
                ),
                (
                  Icons.mail_outline,
                  l10n.profileEmail,
                  user.email ?? l10n.profileEmailMissing,
                ),
              ],
            ),
          ),
          const Gap.xl(),
          FadeSlideIn(
            index: 1,
            child: AppListGroup(
              children: [
                AppListRow(
                  icon: Icons.edit_outlined,
                  title: l10n.profileEdit,
                  onTap: editProfile,
                ),
                // Only for someone an owner made a gate attendant.
                if (!user.isOwner && hasGate)
                  AppListRow(
                    icon: Icons.qr_code_scanner,
                    title: l10n.profileGate,
                    subtitle: l10n.profileGateHint,
                    onTap: () => context.push(Routes.gate),
                  ),
                // Apply, or see an application waiting for review.
                if (!user.isOwner)
                  AppListRow(
                    icon: Icons.storefront_outlined,
                    title: l10n.profileOwnerApplication,
                    subtitle: l10n.profileOwnerApplicationHint,
                    onTap: () => context.push(Routes.owner),
                  ),
                if (user.isOwner)
                  AppListRow(
                    icon: Icons.description_outlined,
                    title: l10n.profileDocuments,
                    onTap: () => context.push(Routes.ownerProfileDocuments),
                  ),
                if (user.isOwner)
                  AppListRow(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.gstTitle,
                    subtitle: l10n.profileGstHint,
                    onTap: () => context.push(Routes.ownerProfileGst),
                  ),
                AppListRow(
                  icon: Icons.help_outline,
                  title: l10n.profileHelp,
                  onTap: () => context.push(
                    user.isOwner ? Routes.ownerProfileHelp : Routes.profileHelp,
                  ),
                ),
              ],
            ),
          ),
          const Gap.lg(),
          FadeSlideIn(
            index: 2,
            child: AppListGroup(
              children: [
                AppListRow(
                  icon: Icons.logout,
                  title: l10n.profileSignOut,
                  isDestructive: true,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const Gap.xl(),
        ],
      ),
    );
  }
}

/// The person at the top of Profile: initials, name, and how to reach them.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.rows});

  final String? name;
  final List<(IconData icon, String label, String value)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.card(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: name),
                const Gap.lg(),
                Expanded(
                  child: Text(
                    name ?? l10n.profileNameMissing,
                    style: text.h2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap.lg(),
            const Divider(height: AppSize.borderWidth),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: AppSize.iconSmall,
                        color: colors.textSecondary,
                      ),
                      const Gap.md(),
                      Text(
                        label,
                        style: text.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const Gap.lg(),
                      Expanded(
                        child: Text(
                          value,
                          style: text.body,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
