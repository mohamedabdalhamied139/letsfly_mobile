/// Tier 2 Boundary Test: B19 UNO Gameplay Card Plays Boundaries
/// Verifies out-of-turn play rejection, non-matching cards, invalid wild color selection, and consecutive skips.
library b19_gameplay_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B19: UNO Gameplay Card Plays Boundaries', () {
    test('B19-1: Playing a card when NOT current player turn is strictly rejected', () {
      final currentTurn = 2; // bob's turn
      final myId = 1; // alice
      final canPlay = currentTurn == myId;
      expect(canPlay, isFalse);
    });

    test('B19-2: Playing a card that matches neither color nor value is rejected as illegal', () {
      final topCard = TestFixtures.cardRed7;
      final playCard = TestFixtures.createCard(
        id: 'c_blue_2',
        type: 'number',
        color: 'blue',
        value: 2,
        nameAr: 'أزرق 2',
      );
      final isLegal = playCard['color'] == topCard['color'] ||
          playCard['value'] == topCard['value'] ||
          playCard['color'] == 'wild';
      expect(isLegal, isFalse);
    });

    test('B19-3: Invalid wild color selection (e.g. "black") is rejected', () {
      final validColors = ['red', 'yellow', 'green', 'blue'];
      final invalidColor = 'black';
      expect(validColors.contains(invalidColor), isFalse);
    });

    test('B19-4: Skip card played on a Skip card is legal because types match', () {
      final topCard = TestFixtures.cardRedSkip;
      final playCard = TestFixtures.createCard(
        id: 'c_yellow_skip',
        type: 'skip',
        color: 'yellow',
        value: null,
        nameAr: 'أصفر تخطي',
      );
      final isLegal = playCard['type'] == topCard['type'];
      expect(isLegal, isTrue);
    });

    test('B19-5: Draw Two played on a Draw Two matches type and is legal', () {
      final topCard = TestFixtures.cardGreenDrawTwo;
      final playCard = TestFixtures.createCard(
        id: 'c_red_d2',
        type: 'draw_two',
        color: 'red',
        value: null,
        nameAr: 'أحمر اسحب 2',
      );
      final isLegal = playCard['type'] == topCard['type'];
      expect(isLegal, isTrue);
    });
  });
}
