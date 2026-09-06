import 'package:flutter/widgets.dart';

/// Contract for application localization service.
/// Conforms strictly to PROJECT.md § Interface Contracts.
abstract class LocalizationService {
  /// Currently active locale ('ar' or 'en')
  Locale get currentLocale;

  /// Text direction: RTL for Arabic, LTR for English
  TextDirection get textDirection;

  /// Switch language dynamically at runtime without app restart ('ar' or 'en')
  Future<void> setLanguage(String langCode);

  /// Translate a key with optional parametric arguments
  String translate(String key, {Map<String, dynamic>? args});

  /// Resolve dynamic server-generated Arabic action messages into localized English
  String resolveDynamicPattern(String serverMessage);

  /// Reactive stream of locale changes
  Stream<Locale> get localeStream;
}
