import 'package:flutter/widgets.dart';

import 'localization_service.dart';

/// Flutter integration wrapper for Let's Fly localization.
class AppLocalizations {
  final LocalizationService service;

  AppLocalizations(this.service);

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, 'No AppLocalizations found in context');
    return instance!;
  }

  String translate(String key, {Map<String, dynamic>? args}) =>
      service.translate(key, args: args);

  String resolveDynamicPattern(String serverMessage) =>
      service.resolveDynamicPattern(serverMessage);

  Locale get currentLocale => service.currentLocale;
  TextDirection get textDirection => service.textDirection;
  bool get isRtl => textDirection == TextDirection.rtl;
}

/// Convenience extensions on BuildContext for clean UI code.
extension LocalizationContextExtension on BuildContext {
  /// Translate a key with optional arguments
  String tr(String key, {Map<String, dynamic>? args}) {
    return AppLocalizations.of(this).translate(key, args: args);
  }

  /// Translate a dynamic server action message via regex patterns
  String trPattern(String serverMessage) {
    return AppLocalizations.of(this).resolveDynamicPattern(serverMessage);
  }

  /// Check if the active locale is Right-to-Left (Arabic)
  bool get isRtl {
    return AppLocalizations.of(this).isRtl;
  }
}
