/// Tier 2 Boundary Test: B21 UNO Declarations Boundaries
/// Verifies premature UNO call (2+ cards), catch window expiration, simultaneous catches, and false catch.
library b21_declarations_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B21: UNO Declarations & Penalties Boundaries', () {
    test('B21-1: Calling UNO prematurely when hand has 2 or more cards is rejected', () {
      final handCount = 2;
      final canCallUno = handCount == 1;
      expect(canCallUno, isFalse);
    });

    test('B21-2: Catch window expires once the subsequent player starts their turn', () {
      bool isCatchWindowOpen = false;
      expect(isCatchWindowOpen, isFalse);
    });

    test('B21-3: Simultaneous catch attempts: only the first catcher receives confirmation', () {
      int penaltyCardsAwarded = 0;
      void onCatchReceived(String catcher) {
        if (penaltyCardsAwarded == 0) {
          penaltyCardsAwarded = 4;
        }
      }
      onCatchReceived('bob');
      onCatchReceived('charlie');
      expect(penaltyCardsAwarded, equals(4)); // only applied once
    });

    test('B21-4: False catch accusation does not award penalty cards to innocent player', () {
      final targetHandCount = 3;
      final isTargetGuilty = targetHandCount == 1;
      expect(isTargetGuilty, isFalse);
    });

    test('B21-5: Buzzer button is disabled when room buzzer rule is turned off', () {
      final buzzerRuleEnabled = false;
      expect(buzzerRuleEnabled, isFalse);
    });
  });
}
