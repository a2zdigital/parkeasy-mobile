import 'package:app/app/routes.dart';
import 'package:app/core/config/app_identity.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/features/auth/state/registration_role.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegistrationRoleScreen extends StatefulWidget {
  const RegistrationRoleScreen({super.key});

  @override
  State<RegistrationRoleScreen> createState() => _RegistrationRoleScreenState();
}

class _RegistrationRoleScreenState extends State<RegistrationRoleScreen> {
  RegistrationRole? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.registrationRoleTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap.xl(),
          Text(
            l10n.registrationRoleQuestion(appDisplayName),
            style: context.text.h1,
          ),
          const Gap.lg(),
          _RoleOption(
            title: l10n.registrationOwnerTitle,
            description: l10n.registrationOwnerDescription,
            selected: _selected == RegistrationRole.owner,
            onTap: () => setState(() => _selected = RegistrationRole.owner),
          ),
          const Gap.md(),
          _RoleOption(
            title: l10n.registrationCustomerTitle,
            description: l10n.registrationCustomerDescription,
            selected: _selected == RegistrationRole.customer,
            onTap: () => setState(() => _selected = RegistrationRole.customer),
          ),
        ],
      ),
      bottom: PrimaryButton(
        label: l10n.nameContinue,
        onPressed: _selected == null
            ? null
            : () => context.push(Routes.registrationPhone, extra: _selected),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$title. $description',
    child: AppCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.h3),
                const Gap.xs(),
                Text(
                  description,
                  style: context.text.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Gap.md(),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: AppSize.icon,
            color: selected
                ? context.colors.primary
                : context.colors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
