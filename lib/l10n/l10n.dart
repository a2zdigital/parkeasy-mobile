import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:app/l10n/generated/app_localizations.dart';

/// The app's text, from a widget: `context.l10n.phoneTitle`.
extension Localised on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
