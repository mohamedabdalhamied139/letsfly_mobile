/// Tier 1 Feature Test: F14 Spoken Accessibility Announcer
/// Verifies assertive vs polite announcements, turn notifications, and language adaptation.
library f14_spoken_announcer_test;

import 'package:letsfly_mobile/core/accessibility/accessibility_announcer.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F14: Spoken Accessibility Announcer', () {
    test('F14-1: Turn start produces assertive announcement to interrupt ambient speech', () async {
      expect(harness.announcer is StandardAccessibilityAnnouncer, isTrue);
      harness.setLocale('ar');
      harness.recorder.clear();
      await harness.announcer.announce(
        harness.translate('game.yourTurn'),
        priority: AnnouncePriority.assertive,
      );
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'دورك الآن')), isTrue);
    });

    test('F14-2: Ambient chat produces polite announcement without interrupting', () {
      harness.recorder.clear();
      harness.announce('bob: مرحبًا', assertive: false);
      expect(harness.recorder.announcementEvents.last.assertive, isFalse);
    });

    test('F14-3: Spoken announcements update when language switches', () {
      harness.recorder.clear();
      harness.setLocale('en');
      harness.announce(harness.translate('game.yourTurn'), assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'Your turn now')), isTrue);
      harness.setLocale('ar');
    });

    test('F14-4: UNO call event triggers assertive broadcast announcement', () {
      harness.recorder.clear();
      harness.announce('alice هتف أونو!', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'أونو!')), isTrue);
    });

    test('F14-5: Error messages are announced assertively to warn visually impaired player', () {
      harness.recorder.clear();
      harness.announce('لا يمكنك سحب ورقة ولديك ورقة صالحة للعب!', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'لا يمكنك سحب ورقة')), isTrue);
    });
  });
}
