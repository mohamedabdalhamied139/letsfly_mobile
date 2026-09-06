import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import 'package:letsfly_mobile/core/localization/pattern_resolver.dart';
import 'package:letsfly_mobile/core/localization/locale_cubit.dart';

void main() {
  late String arJson;
  late String enJson;
  late String patternsJson;
  late TranslationManager translationManager;

  setUpAll(() {
    arJson = File('assets/locales/ar.json').readAsStringSync();
    enJson = File('assets/locales/en.json').readAsStringSync();
    patternsJson = File('assets/locales/patterns.json').readAsStringSync();
  });

  setUp(() {
    translationManager = TranslationManager();
    translationManager.loadCatalogsFromRaw(
      arRaw: arJson,
      enRaw: enJson,
      patRaw: patternsJson,
    );
  });

  group('TranslationManager Catalog Loading & Direct Translation', () {
    test('loads all 1552 keys into Arabic and English catalogs', () {
      expect(translationManager.arCatalog.length, equals(1552));
      expect(translationManager.enCatalog.length, equals(1552));
      expect(translationManager.enToArReverse.isNotEmpty, isTrue);
    });

    test('direct lookup in Arabic mode', () {
      translationManager.setLanguage('ar');
      expect(translationManager.translate('القائمة الرئيسية'), equals('القائمة الرئيسية'));
      expect(translationManager.translate('بدء اللعبة'), equals('بدء اللعبة'));
      expect(translationManager.translate('أحمر'), equals('أحمر'));
    });

    test('direct lookup in English mode', () {
      translationManager.setLanguage('en');
      expect(translationManager.translate('القائمة الرئيسية'), equals('Main Menu'));
      expect(translationManager.translate('بدء اللعبة'), equals('Start Game'));
      expect(translationManager.translate('أحمر'), equals('Red'));
    });

    test('reverse lookup in Arabic mode from English key', () {
      translationManager.setLanguage('ar');
      expect(translationManager.translate('Main Menu'), equals('القائمة الرئيسية'));
      expect(translationManager.translate('Start Game'), equals('بدء اللعبة'));
    });

    test('trailing punctuation handling', () {
      translationManager.setLanguage('en');
      expect(translationManager.translate('القائمة الرئيسية.'), equals('Main Menu.'));
      expect(translationManager.translate('هل أنت متأكد؟'), equals('Are you sure?'));

      translationManager.setLanguage('ar');
      expect(translationManager.translate('Are you sure?'), equals('هل أنت متأكد؟'));
    });

    test('parameter interpolation', () {
      translationManager.setLanguage('en');
      final translated = translationManager.translate(
        'مرحباً {name}، رصيدك {score}',
        args: {'name': 'Zaid', 'score': 100},
      );
      expect(translated, contains('Zaid'));
      expect(translated, contains('100'));
    });
  });

  group('Dynamic Language Switching & Directionality', () {
    test('instant language switch updates locale and text direction', () async {
      await translationManager.setLanguage('ar');
      expect(translationManager.currentLocale.languageCode, equals('ar'));
      expect(translationManager.textDirection, equals(TextDirection.rtl));

      await translationManager.setLanguage('en');
      expect(translationManager.currentLocale.languageCode, equals('en'));
      expect(translationManager.textDirection, equals(TextDirection.ltr));
    });

    test('LocaleCubit reflects language switches and toggling', () async {
      final cubit = LocaleCubit(translationManager);
      expect(cubit.state.locale.languageCode, equals('en'));

      await cubit.setLanguage('ar');
      expect(cubit.state.locale.languageCode, equals('ar'));
      expect(cubit.state.isRtl, isTrue);

      await cubit.toggleLanguage();
      expect(cubit.state.locale.languageCode, equals('en'));
      expect(cubit.state.isRtl, isFalse);

      await cubit.close();
    });
  });

  group('PatternResolver Dynamic Regex Translation (Python Client Parity)', () {
    test('translates UNO card patterns correctly', () {
      translationManager.setLanguage('en');
      expect(translationManager.resolveDynamicPattern('أحمر 7'), equals('Red 7'));
      expect(translationManager.resolveDynamicPattern('أصفر 0'), equals('Yellow 0'));
      expect(translationManager.resolveDynamicPattern('أزرق سحب 2'), equals('Blue Draw Two'));
      expect(translationManager.resolveDynamicPattern('أخضر تخطي'), equals('Green Skip'));
      expect(translationManager.resolveDynamicPattern('أحمر عكس الاتجاه'), equals('Red Reverse'));
      expect(translationManager.resolveDynamicPattern('تبديل اللون وسحب 4'), equals('Wild Draw Four'));
      expect(translationManager.resolveDynamicPattern('تبديل اللون'), equals('Wild'));
    });

    test('preserves dynamic usernames and numbers untouched', () {
      translationManager.setLanguage('en');
      // User 'أحمد' played 'أحمر 7'
      final result1 = translationManager.resolveDynamicPattern('أحمد لعب أحمر 7');
      expect(result1, equals('أحمد played Red 7'));

      // User 'Sarah' rolled a 6
      final result2 = translationManager.resolveDynamicPattern('رمى Sarah 6.');
      expect(result2, equals('Sarah rolled a 6.'));

      // User 'Mido' presence
      final result3 = translationManager.resolveDynamicPattern('Mido (متصل)');
      expect(result3, equals('Mido (Online)'));
    });

    test('resolves points and score summaries', () {
      translationManager.setLanguage('en');
      final result = translationManager.resolveDynamicPattern('أحمد: 50 نقاط');
      expect(result, contains('points'));
      expect(result, contains('50'));
    });

    test('safe fallback when message does not match any pattern', () {
      translationManager.setLanguage('en');
      const unknown = 'رسالة عشوائية غير معروفة للنظام 12345';
      expect(translationManager.resolveDynamicPattern(unknown), equals(unknown));
    });

    test('preserves Arabic when in Arabic mode', () {
      translationManager.setLanguage('ar');
      expect(translationManager.resolveDynamicPattern('أحمر 7'), equals('أحمر 7'));
      expect(translationManager.resolveDynamicPattern('أحمد لعب أحمر 7'), equals('أحمد لعب أحمر 7'));
    });
  });
}
