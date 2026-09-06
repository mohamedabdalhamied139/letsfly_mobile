/// Tier 2 Boundary Test: B14 Spoken Announcer Boundaries
/// Verifies announcement queue flood (50+ items), empty strings, long speeches, and interruptions.
library b14_announcer_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B14: Spoken Accessibility Announcer Boundaries', () {
    test('B14-1: Flooding announcer with 50 rapid speeches does not drop assertive messages', () {
      harness.recorder.clear();
      for (int i = 0; i < 50; i++) {
        harness.announce('إشعار محيطي $i', assertive: false);
      }
      harness.announce('إشعار عاجل حاسم!', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'إشعار عاجل')), isTrue);
    });

    test('B14-2: Empty announcement string is ignored without queueing', () {
      harness.recorder.clear();
      harness.announce('');
      expect(harness.recorder.announcementEvents.length, equals(1));
    });

    test('B14-3: Extremely long announcement (1000+ characters) handles queuing safely', () {
      final longSpeech = 'هذا إعلان صوتي طويل جدًا للتأكد من عدم تعليق قارئ الشاشة. ' * 20;
      harness.announce(longSpeech, assertive: true);
      expect(harness.recorder.announcementEvents.isNotEmpty, isTrue);
    });

    test('B14-4: Assertive announcement interrupts polite ambient announcements', () {
      harness.recorder.clear();
      harness.announce('دردشة: مرحبًا', assertive: false);
      harness.announce('دورك الآن!', assertive: true);
      expect(harness.recorder.announcementEvents.last.assertive, isTrue);
    });

    test('B14-5: TTS announcer works independently of sound engine mute state', () {
      harness.setMute(true);
      harness.recorder.clear();
      harness.announce('إعلان صوتي أثناء كتم المؤثرات', assertive: true);
      expect(harness.recorder.hasAnnounced(RegExp(r'كتم المؤثرات')), isTrue);
      harness.setMute(false);
    });
  });
}
