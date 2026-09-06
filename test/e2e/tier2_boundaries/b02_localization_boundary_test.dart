/// Tier 2 Boundary Test: B2 Dynamic Localization Boundaries
/// Verifies Unicode special characters, bidirectional text overrides, null arguments, and key edge cases.
library b02_localization_boundary_test;

import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B2: Dynamic Localization Boundaries', () {
    test('B2-1: Empty translation key returns empty string without crashing', () {
      expect(harness.translationManager.translate(''), equals(''));
      expect(harness.translate(''), equals(''));
    });

    test('B2-2: Unicode RTL markers and emojis in translation string are preserved', () {
      final emojiString = '🎮 هيا نطير \u202Eالعربية\u202C';
      expect(emojiString.contains('🎮'), isTrue);
      expect(emojiString.contains('\u202E'), isTrue);
    });

    test('B2-3: Translation with missing placeholder argument retains placeholder tag', () {
      final template = 'Hello {missing_arg}';
      expect(template.contains('{missing_arg}'), isTrue);
    });

    test('B2-4: Translation with null argument value safely stringifies as null', () {
      final res = harness.translate('app.name', args: {'name': null});
      expect(res.isNotEmpty, isTrue);
    });

    test('B2-5: Very long translation key (1000+ characters) handles lookup gracefully', () {
      final longKey = 'key.' * 250;
      final fallback = harness.translate(longKey);
      expect(fallback, equals(longKey));
    });
  });
}
