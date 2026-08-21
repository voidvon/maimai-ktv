import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String pitchShiftLabel(int semitones) {
    if (semitones == 0) {
      return l10n.originalKey;
    }
    final String value = semitones > 0 ? '+$semitones' : '$semitones';
    return l10n.pitchShiftValue(value);
  }
}
