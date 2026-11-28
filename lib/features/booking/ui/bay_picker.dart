import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/booking/data/models/bay_option.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Icons and names for what a bay offers.
IconData bayFeatureIcon(String feature) => switch (feature) {
  BayFeatures.accessible => Icons.accessible,
  BayFeatures.ev => Icons.ev_station_outlined,
  BayFeatures.covered => Icons.roofing,
  _ => Icons.local_parking_outlined,
};

String bayFeatureName(BuildContext context, String feature) {
  final l10n = context.l10n;
  return switch (feature) {
    BayFeatures.accessible => l10n.bayFeatureAccessible,
    BayFeatures.ev => l10n.bayFeatureEv,
    BayFeatures.covered => l10n.bayFeatureCovered,
    _ => feature,
  };
}

/// Choosing a numbered bay: "Any free bay" (the default) or one of the free
/// bays, each with icons for what it offers. Taken bays are shown but
/// cannot be chosen, so the customer sees why a favourite is missing.
class BayPicker extends StatelessWidget {
  const BayPicker({
    required this.bays,
    required this.chosenId,
    required this.onChoose,
    super.key,
  });

  final List<BayOption> bays;
  final String? chosenId;
  final ValueChanged<String?> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.bayChooseTitle, style: text.h3),
        const Gap.md(),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.bayAny),
              selected: chosenId == null,
              onSelected: (_) => onChoose(null),
            ),
            for (final bay in bays)
              Tooltip(
                message: bay.features
                    .map((f) => bayFeatureName(context, f))
                    .join(', '),
                child: ChoiceChip(
                  avatar: bay.features.isEmpty
                      ? null
                      : Icon(
                          bayFeatureIcon(bay.features.first),
                          size: AppSize.iconSmall,
                        ),
                  label: Text(
                    bay.available ? bay.label : l10n.bayTaken(bay.label),
                    semanticsLabel: [
                      bay.available ? bay.label : l10n.bayTaken(bay.label),
                      ...bay.features.map((f) => bayFeatureName(context, f)),
                    ].join(', '),
                  ),
                  selected: chosenId == bay.id,
                  onSelected: bay.available ? (_) => onChoose(bay.id) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
