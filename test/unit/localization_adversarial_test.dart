import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';

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

  group('Adversarial Challenge: Complex Patterns & Dynamic Data', () {
    test('UNO complex and special patterns', () {
      translationManager.setLanguage('en');
      expect(translationManager.resolveDynamicPattern('أحمر 7'), equals('Red 7'));
      expect(translationManager.resolveDynamicPattern('أصفر 0'), equals('Yellow 0'));
      expect(translationManager.resolveDynamicPattern('أزرق سحب 2'), equals('Blue Draw Two'));
      expect(translationManager.resolveDynamicPattern('أخضر تخطي'), equals('Green Skip'));
      expect(translationManager.resolveDynamicPattern('أحمر عكس الاتجاه'), equals('Red Reverse'));
      expect(translationManager.resolveDynamicPattern('تبديل اللون وسحب 4'), equals('Wild Draw Four'));
      expect(translationManager.resolveDynamicPattern('تبديل اللون'), equals('Wild'));
      expect(translationManager.resolveDynamicPattern('بنفسجي سحب 5'), equals('Purple Draw Five'));
      expect(translationManager.resolveDynamicPattern('تركوازي جرس'), equals('Teal Buzzer'));
      expect(translationManager.resolveDynamicPattern('وردي إسقاط الكل'), equals('Pink Discard All'));
    });

    test('Usernames with digits, underscores, and special characters', () {
      translationManager.setLanguage('en');
      expect(
        translationManager.resolveDynamicPattern('Player123 لعب أحمر 7'),
        equals('Player123 played Red 7'),
      );
      expect(
        translationManager.resolveDynamicPattern('[VIP]Zaid_99 لعب أزرق سحب 2'),
        equals('[VIP]Zaid_99 played Blue Draw Two'),
      );
      expect(
        translationManager.resolveDynamicPattern('user_name_007 لعب أخضر تخطي'),
        equals('user_name_007 played Green Skip'),
      );
      expect(
        translationManager.resolveDynamicPattern('bot#4 (صعب) لعب أصفر 0'),
        equals('bot#4 (صعب) played Yellow 0'),
      );
      // Fails due to priority inversion with generic catch-all
      expect(
        translationManager.resolveDynamicPattern('gamer_99 (متصل)'),
        equals('gamer_99 (Online)'),
      );
    });

    test('Arabic diacritics (tashkeel) preservation', () {
      translationManager.setLanguage('en');
      expect(
        translationManager.resolveDynamicPattern('مُحَمَّد لعب أحمر 7'),
        equals('مُحَمَّد played Red 7'),
      );
      expect(
        translationManager.resolveDynamicPattern('أَحْمَدُ: 100 نقاط'),
        equals('أَحْمَدُ: 100 points'),
      );
    });

    test('Nested formatting and multi-clause stats', () {
      translationManager.setLanguage('en');
      expect(
        translationManager.resolveDynamicPattern(
          'نهاية الجولة 1: فاز أحمد. نقاط الجولة (50). النتيجة الكلية: 150، الهدف 500.',
        ),
        equals(
          'End of round 1: فاز أحمد. Round points (50). Overall score: 150, Target 500.',
        ),
      );
      // Fails due to buggy comma clause splitting intercepting pattern
      expect(
        translationManager.resolveDynamicPattern('أحمد: لعب 10، فزت 5، خسرت 5'),
        equals('أحمد: played 10, you won 5, you lost 5'),
      );
    });
  });

  group('Adversarial Challenge: Edge Cases & Desktop Client Parity', () {
    test('Arabic-comma error pattern not prematurely truncated', () {
      translationManager.setLanguage('en');
      // Fails: Dart returns "Game started، لكن تعذر تحميل الكروت: خطأ في الاتصال"
      expect(
        translationManager.resolveDynamicPattern(
          'بدأت اللعبة، لكن تعذر تحميل الكروت: خطأ في الاتصال',
        ),
        equals('Game started, but failed to load cards: خطأ في الاتصال'),
      );
    });

    test('List translation does not translate partially unknown lists', () {
      translationManager.setLanguage('en');
      // Fails: Dart returns "Red and لاعب1"
      expect(
        translationManager.resolveDynamicPattern('أحمر و لاعب1'),
        equals('أحمر و لاعب1'),
      );
    });

    test('Missing compound prefix handlers ("شرح " and "اختصارات ")', () {
      translationManager.setLanguage('en');
      // Fails: Dart returns untranslated "شرح أونو"
      expect(
        translationManager.translate('شرح أونو'),
        equals('UNO Guide'),
      );
    });

    test('Reverse mapping and punctuation handling', () {
      translationManager.setLanguage('ar');
      expect(translationManager.translate('Are you sure?'), equals('هل أنت متأكد؟'));
      expect(translationManager.translate('Main Menu.'), equals('القائمة الرئيسية.'));
      expect(translationManager.resolveDynamicPattern('Are you sure?'), equals('هل أنت متأكد؟'));
      expect(translationManager.resolveDynamicPattern('Main Menu.'), equals('القائمة الرئيسية.'));
    });

    test('Unknown string fallback', () {
      translationManager.setLanguage('en');
      const unkAr = 'هذه رسالة فريدة عشوائية بالكامل 98765';
      const unkEn = 'This is an uncataloged English server broadcast';
      expect(translationManager.resolveDynamicPattern(unkAr), equals(unkAr));
      expect(translationManager.resolveDynamicPattern(unkEn), equals(unkEn));

      translationManager.setLanguage('ar');
      expect(translationManager.resolveDynamicPattern(unkAr), equals(unkAr));
      expect(translationManager.resolveDynamicPattern(unkEn), equals(unkEn));
    });
  });
}
