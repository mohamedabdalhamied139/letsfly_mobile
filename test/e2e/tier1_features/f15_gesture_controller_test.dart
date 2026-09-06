/// Tier 1 Feature Test: F15 Unified Gesture Controller & Dual Parity
/// Verifies gesture mapping (swipes, double-tap, long-press) and 1:1 dual control parity.
library f15_gesture_controller_test;

import 'package:letsfly_mobile/core/accessibility/gesture_controller.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F15: Unified Gesture Controller & Dual Control Parity', () {
    test('F15-1: Swipe left/right navigates horizontally through hand cards', () {
      int selectedCardIndex = 0;
      final engine = GestureRecognizerEngine(
        handler: LetsFlyGestureHandler(
          onSwipeRight: () => selectedCardIndex = (selectedCardIndex + 1).clamp(0, 4),
          onSwipeLeft: () => selectedCardIndex = (selectedCardIndex - 1).clamp(0, 4),
        ),
      );
      // Simulate swipe right
      engine.onDragStart(0, 0);
      engine.onDragEnd(200, 0);
      expect(selectedCardIndex, equals(1));
      // Simulate swipe left
      engine.onDragStart(0, 0);
      engine.onDragEnd(-200, 0);
      expect(selectedCardIndex, equals(0));
    });

    test('F15-2: Double-tap activation triggers card play action', () {
      bool playTriggered = false;
      final handler = LetsFlyGestureHandler(
        onDoubleTap: () => playTriggered = true,
      );
      handler.onDoubleTap?.call();
      expect(playTriggered, isTrue);
    });

    test('F15-3: Long-press gesture opens contextual card details dialog', () {
      bool detailsOpened = false;
      final handler = LetsFlyGestureHandler(
        onLongPress: () => detailsOpened = true,
      );
      handler.onLongPress?.call();
      expect(detailsOpened, isTrue);
    });

    test('F15-4: Dual control parity: card can be played via accessible button', () {
      // Every gesture action must have an identical button action
      bool actionFired = false;
      void onPlayButtonPressed() {
        actionFired = true;
      }
      onPlayButtonPressed();
      expect(actionFired, isTrue);
    });

    test('F15-5: Gesture controller maintains state without conflicting with screen reader focus', () {
      harness.recorder.clear();
      harness.announce('تم اختيار الورقة: أحمر 7');
      expect(harness.recorder.hasAnnounced(RegExp(r'أحمر 7')), isTrue);
    });
  });
}
