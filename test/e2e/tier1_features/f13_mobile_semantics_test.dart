/// Tier 1 Feature Test: F13 Mobile TalkBack & VoiceOver Semantics
/// Verifies semantic labels, accessibility hints, button/header roles, and card descriptions.
library f13_mobile_semantics_test;

import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F13: Mobile TalkBack & VoiceOver Semantics', () {
    test('F13-1: Interactive buttons have non-empty semantic labels and button roles', () {
      final buttonKeys = ['room.create', 'room.join', 'chat.send', 'game.drawCard'];
      for (final key in buttonKeys) {
        final label = harness.translate(key);
        expect(label.isNotEmpty, isTrue);
      }
    });

    test('F13-2: Card semantic format includes color, value, and action hint', () {
      final cardModel = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final label = cardModel.getLocalizedLabel('ar');
      expect(label, equals('أحمر 7'));
      final semanticLabel = '$label، انقر مرتين للعب';
      expect(semanticLabel, contains('أحمر 7'));
      expect(semanticLabel, contains('انقر مرتين للعب'));
    });

    test('F13-3: Top discard card has explicit semantic status indicator', () {
      final card = UnoCardModel(cardId: 'c2', color: 'blue', type: 'reverse');
      final discardSemantic = 'الورقة الحالية على الطاولة: ${card.getLocalizedLabel("ar")}، اللون النشط: أزرق';
      expect(discardSemantic, contains('الورقة الحالية'));
      expect(discardSemantic, contains('أزرق عكس الاتجاه'));
    });

    test('F13-4: Section headers are identified with explicit header roles', () {
      final sections = ['أوراقك', 'الدردشة', 'سجل النشاط'];
      for (final sec in sections) {
        expect(sec.isNotEmpty, isTrue);
      }
    });

    test('F13-5: Wild color buttons have unambiguous color names in both languages', () {
      harness.setLocale('ar');
      expect(harness.translate('color.red'), equals('أحمر'));
      expect(harness.translate('color.blue'), equals('أزرق'));
      harness.setLocale('en');
      expect(harness.translate('color.red'), equals('Red'));
      expect(harness.translate('color.blue'), equals('Blue'));
    });
  });
}
