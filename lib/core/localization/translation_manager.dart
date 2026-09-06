import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localization_service.dart';
import 'pattern_resolver.dart';

/// Production-ready translation and dynamic pattern resolution manager for Let's Fly.
/// Mirrors the authoritative behavior of the desktop client's TranslationManager.
class TranslationManager extends ChangeNotifier implements LocalizationService {
  static const String prefLanguage = 'general_language_preference';

  Locale _currentLocale = const Locale('ar');
  TextDirection _textDirection = TextDirection.rtl;

  Map<String, String> _arCatalog = {};
  Map<String, String> _enCatalog = {};
  final Map<String, String> _enToArReverse = {};

  PatternResolver? _patternResolver;
  final StreamController<Locale> _localeController = StreamController<Locale>.broadcast();
  bool _initialized = false;

  TranslationManager();

  @override
  Locale get currentLocale => _currentLocale;

  @override
  TextDirection get textDirection => _textDirection;

  @override
  Stream<Locale> get localeStream => _localeController.stream;

  bool get isInitialized => _initialized;
  Map<String, String> get arCatalog => _arCatalog;
  Map<String, String> get enCatalog => _enCatalog;
  Map<String, String> get enToArReverse => _enToArReverse;
  PatternResolver? get patternResolver => _patternResolver;

  /// Initializes catalogs and patterns from asset bundles or memory maps.
  Future<void> initialize({
    String? arJsonContent,
    String? enJsonContent,
    String? patternsJsonContent,
    SharedPreferences? prefs,
  }) async {
    try {
      final arRaw = arJsonContent ?? await rootBundle.loadString('assets/locales/ar.json');
      final enRaw = enJsonContent ?? await rootBundle.loadString('assets/locales/en.json');
      final patRaw = patternsJsonContent ?? await rootBundle.loadString('assets/locales/patterns.json');

      loadCatalogsFromRaw(arRaw: arRaw, enRaw: enRaw, patRaw: patRaw);

      // Determine initial language preference
      SharedPreferences? sp = prefs;
      if (sp == null) {
        try {
          sp = await SharedPreferences.getInstance();
        } catch (_) {
          sp = null;
        }
      }
      final savedLang = sp?.getString(prefLanguage)?.toLowerCase().trim();
      if (savedLang == 'ar' || savedLang == 'en') {
        _currentLocale = Locale(savedLang!);
      } else {
        // Windows parity: "system" follows the device language.
        final sysLang = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
        _currentLocale = sysLang.startsWith('ar') ? const Locale('ar') : const Locale('en');
      }
      _textDirection = _currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[TranslationManager] Initialization error: $e');
    }
  }

  /// Synchronous catalog loader useful for unit tests and runtime reloads.
  void loadCatalogsFromRaw({
    required String arRaw,
    required String enRaw,
    required String patRaw,
  }) {
    final Map<String, dynamic> arMap = jsonDecode(arRaw);
    final Map<String, dynamic> enMap = jsonDecode(enRaw);
    final List<dynamic> patList = jsonDecode(patRaw);

    _arCatalog = arMap.map((k, v) => MapEntry(k, v.toString()));
    _enCatalog = enMap.map((k, v) => MapEntry(k, v.toString()));

    // Build reverse map with unpunctuated preference
    _enToArReverse.clear();
    for (final entry in _enCatalog.entries) {
      final arKey = entry.key;
      final enVal = entry.value;
      if (arKey.isEmpty || enVal.isEmpty) continue;

      if (!_enToArReverse.containsKey(enVal)) {
        _enToArReverse[enVal] = arKey;
      } else {
        final prev = _enToArReverse[enVal]!;
        if ((prev.endsWith('.') || prev.endsWith('!')) &&
            !(arKey.endsWith('.') || arKey.endsWith('!'))) {
          _enToArReverse[enVal] = arKey;
        }
      }
    }

    _patternResolver = PatternResolver.fromRaw(
      rawPatterns: patList,
      translate: translate,
    );
  }

  @override
  Future<void> setLanguage(String langCode) async {
    final code = langCode.toLowerCase().trim();
    if (code != 'system' && code != 'ar' && code != 'en') return;

    final resolvedCode = code == 'system'
        ? (PlatformDispatcher.instance.locale.languageCode.toLowerCase().startsWith('ar') ? 'ar' : 'en')
        : code;
    if (_currentLocale.languageCode == resolvedCode &&
        (code != 'system' || _currentLocale.languageCode == resolvedCode)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefLanguage, code);
      } catch (_) {}
      return;
    }

    _currentLocale = Locale(resolvedCode);
    _textDirection = resolvedCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLanguage, code);
    } catch (_) {
      // Ignore if shared preferences is unavailable
    }

    _localeController.add(_currentLocale);
    notifyListeners();
  }

  @override
  String translate(String key, {Map<String, dynamic>? args}) {
    if (key.isEmpty) return key;

    final translated = _trBase(key);
    if (args == null || args.isEmpty) {
      return translated;
    }

    var result = translated;
    args.forEach((k, v) {
      result = result.replaceAll('{$k}', v?.toString() ?? '');
    });
    return result;
  }

  @override
  String resolveDynamicPattern(String serverMessage) {
    if (serverMessage.isEmpty) return serverMessage;
    // Route both Arabic and English through _trBase to preserve punctuation stripping,
    // list translation, and full catalog pipeline parity with client/localization.py
    return _trBase(serverMessage);
  }

  String _trBase(String s) {
    final active = _currentLocale.languageCode;

    // Arabic mode
    if (active == 'ar') {
      if (_arCatalog.containsKey(s)) return _arCatalog[s]!;
      if (_enToArReverse.containsKey(s)) return _enToArReverse[s]!;

      // Comma-separated list splitting: require every member to translate
      for (final sep in const ['، ', ', ', ' و ', ' و', ' and ']) {
        if (s.contains(sep)) {
          final parts = s.split(sep);
          final transParts = parts.map((p) => _arCatalog[p] ?? _enToArReverse[p] ?? p).toList();
          var allChanged = parts.isNotEmpty;
          for (var i = 0; i < parts.length; i++) {
            if (transParts[i] == parts[i]) {
              allChanged = false;
              break;
            }
          }
          if (allChanged) {
            return transParts.join(sep);
          }
        }
      }

      // Strip trailing punctuation for reverse lookup
      final stripped = s.trim();
      for (final punct in const ['...', '.', '!', '?', ':', ',']) {
        if (stripped.endsWith(punct)) {
          final core = stripped.substring(0, stripped.length - punct.length).trimRight();
          if (_enToArReverse.containsKey(core)) {
            final transCore = _enToArReverse[core]!;
            final arPunct = punct == '?' ? '؟' : punct;
            final leading = s.substring(0, s.length - s.trimLeft().length);
            return '$leading$transCore$arPunct';
          }
        }
      }
      return s;
    }

    // English mode
    // 1. Exact catalog match
    if (_enCatalog.containsKey(s)) return _enCatalog[s]!;

    // Stripped match (preserving whitespace)
    final stripped = s.trim();
    if (_enCatalog.containsKey(stripped)) {
      final leading = s.substring(0, s.length - s.trimLeft().length);
      final trailing = s.substring(s.trimRight().length);
      return '$leading${_enCatalog[stripped]!}$trailing';
    }

    // Trailing punctuation handling
    for (final punct in const ['...', '.', '!', '؟', '?', ':', '،', ',']) {
      if (stripped.endsWith(punct)) {
        final core = stripped.substring(0, stripped.length - punct.length).trimRight();
        if (_enCatalog.containsKey(core)) {
          final transCore = _enCatalog[core]!;
          final leading = s.substring(0, s.length - s.trimLeft().length);
          final trailingPunct = punct == '؟' ? '?' : punct;
          return '$leading$transCore$trailingPunct';
        }
      }
    }

    // Period fallback
    if (_enCatalog.containsKey('$stripped.')) {
      var trans = _enCatalog['$stripped.']!;
      if (trans.endsWith('.')) trans = trans.substring(0, trans.length - 1);
      final leading = s.substring(0, s.length - s.trimLeft().length);
      final trailing = s.substring(s.trimRight().length);
      return '$leading$trans$trailing';
    }

    // List translation: only when every member matches
    for (final sep in const ['، ', ', ', ' و ', ' و', ' and ']) {
      if (stripped.contains(sep)) {
        final parts = stripped.split(sep);
        final transParts = parts.map((p) => _enCatalog[p] ?? p).toList();
        var allChanged = parts.isNotEmpty;
        for (var i = 0; i < parts.length; i++) {
          if (transParts[i] == parts[i]) {
            allChanged = false;
            break;
          }
        }
        if (allChanged) {
          final leading = s.substring(0, s.length - s.trimLeft().length);
          final trailing = s.substring(s.trimRight().length);
          final joinSep = (sep == ' و ' || sep == ' و') ? ' and ' : sep;
          return '$leading${transParts.join(joinSep)}$trailing';
        }
      }
    }

    // Compound Arabic-comma clauses: only commit when every clause translates
    if (stripped.contains('، ') && !RegExp(r'[.!?؟]\s').hasMatch(stripped)) {
      final parts = stripped.split('، ').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length > 1) {
        final transParts = parts.map(_trBase).toList();
        var allChanged = parts.isNotEmpty;
        for (var i = 0; i < parts.length; i++) {
          if (transParts[i] == parts[i]) {
            allChanged = false;
            break;
          }
        }
        if (allChanged) {
          final leading = s.substring(0, s.length - s.trimLeft().length);
          final trailing = s.substring(s.trimRight().length);
          return '$leading${transParts.join(', ')}$trailing';
        }
      }
    }

    // Dynamic pattern resolver fallback
    if (_patternResolver != null) {
      final patternResolved = _patternResolver!.resolve(s, active);
      if (patternResolved != s) {
        return patternResolved;
      }
    }

    // Known compound phrases fallback
    if (s.startsWith('\u0625\u0639\u062f\u0627\u062f\u0627\u062a ') && !s.startsWith('\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u063a\u064a\u0631')) {
      final remainder = s.substring('\u0625\u0639\u062f\u0627\u062f\u0627\u062a '.length);
      return '${_trBase(remainder)} Settings';
    }
    if (s.startsWith('\u0625\u062c\u0631\u0627\u0621\u0627\u062a ')) {
      final remainder = s.substring('\u0625\u062c\u0631\u0627\u0621\u0627\u062a '.length);
      return '${_trBase(remainder)} Actions';
    }
    if (s.startsWith('\u0634\u0631\u062d ')) {
      final remainder = s.substring('\u0634\u0631\u062d '.length);
      return '${_trBase(remainder)} Guide';
    }
    if (s.startsWith('\u0627خ\u062a\u0635\u0627\u0631\u0627\u062a ')) {
      final remainder = s.substring('\u0627خ\u062a\u0635\u0627\u0631\u0627\u062a '.length);
      return '${_trBase(remainder)} Shortcuts';
    }

    return s;
  }

  @override
  void dispose() {
    _localeController.close();
    super.dispose();
  }
}
