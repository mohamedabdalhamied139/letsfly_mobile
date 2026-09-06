import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'localization_service.dart';

/// Delegate for Flutter MaterialApp localizations.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  final LocalizationService service;

  const AppLocalizationsDelegate(this.service);

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'en'].contains(locale.languageCode.toLowerCase());
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(service));
  }

  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) => false;
}
