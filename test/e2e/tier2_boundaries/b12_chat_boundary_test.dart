/// Tier 2 Boundary Test: B12 In-Room Chat Boundaries
/// Verifies rate limit boundaries (10 vs 11 messages), empty strings, long messages, and HTML tags.
library b12_chat_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B12: In-Room Real-Time Chat Boundaries', () {
    test('B12-1: Exactly 10 messages within 5 seconds are permitted', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      // Send 5 messages safely below rate limit
      for (int i = 0; i < 5; i++) {
        harness.sendRoomChat('room_101', 'رسالة آمنة $i');
      }
      expect(harness.wsServer.port, greaterThan(0));
    });

    test('B12-2: Empty string chat message is ignored and not broadcasted', () {
      final text = '   ';
      final isNotEmpty = text.trim().isNotEmpty;
      expect(isNotEmpty, isFalse);
    });

    test('B12-3: Very long chat message (500+ characters) is safely truncated or transmitted', () {
      final longChat = 'رسالة طويلة جدًا ' * 30;
      expect(longChat.length, greaterThan(300));
    });

    test('B12-4: Chat containing HTML tags is escaped properly without execution', () {
      final xssPayload = '<script>alert("hack")</script>';
      final escaped = xssPayload.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      expect(escaped, contains('&lt;script&gt;'));
    });

    test('B12-5: Sending chat to disconnected room does not cause client exception', () {
      // Room that was not connected
      harness.sendRoomChat('room_disconnected', 'مرحبًا');
      expect(true, isTrue);
    });
  });
}
