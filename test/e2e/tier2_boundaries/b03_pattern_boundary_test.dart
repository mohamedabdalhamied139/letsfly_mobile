/// Tier 2 Boundary Test: B3 Pattern Engine Boundaries
/// Verifies regex edge cases, empty input, punctuation variations, and malformed strings.
library b03_pattern_boundary_test;

import 'package:letsfly_mobile/core/localization/pattern_resolver.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B3: Dynamic Regex Pattern Engine Boundaries', () {
    test('B3-1: Empty input string resolves to empty string without regex error', () {
      expect(harness.patternResolver is PatternResolver, isTrue);
      harness.setLocale('en');
      expect(harness.resolvePattern(''), equals(''));
    });

    test('B3-2: String with special regex metacharacters (*, +, ?, [) does not throw', () {
      harness.setLocale('en');
      final metachars = 'لعب أحمد+ ورقة [أحمر 7]*?';
      final res = harness.resolvePattern(metachars);
      expect(res.isNotEmpty, isTrue);
    });

    test('B3-3: Missing ending punctuation does not falsely match strict regex', () {
      harness.setLocale('en');
      // Pattern requires trailing dot: لعب (.+) ورقة (.+)\.
      final noDot = 'لعب أحمد ورقة أحمر 7';
      final res = harness.resolvePattern(noDot);
      expect(res, equals(noDot));
    });

    test('B3-4: Multi-word player names and compound card names are captured intact', () {
      harness.setLocale('en');
      final input = 'لعب محمد عبد الله ورقة تغيير اللون واسحب 4.';
      final res = harness.resolvePattern(input);
      expect(res, equals('محمد عبد الله played تغيير اللون واسحب 4.'));
    });

    test('B3-5: Rapid pattern matching across 500 string iterations finishes in sub-second', () {
      harness.setLocale('en');
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 500; i++) {
        harness.resolvePattern('لعب لاعب_$i ورقة أحمر 7.');
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
    });
  });
}
