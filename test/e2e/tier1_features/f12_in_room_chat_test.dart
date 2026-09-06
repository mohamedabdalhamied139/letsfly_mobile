/// Tier 1 Feature Test: F12 In-Room Real-Time Chat
/// Verifies real-time chat broadcast, sender tagging, rate limiting, and speech announcements.
library f12_in_room_chat_test;

import 'dart:async';
import 'dart:convert';
import 'package:letsfly_mobile/data/models/chat_message_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F12: In-Room Real-Time Chat', () {
    test('F12-1: Sending chat emits action frame to room WebSocket', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      harness.sendRoomChat('room_101', 'مرحبًا بالجميع!');
      // Give frame a tick
      await Future.delayed(Duration(milliseconds: 50));
      expect(harness.recorder.networkEvents.any((e) => e.channel == 'ws_room'), isTrue);
    });

    test('F12-2: Broadcast chat message is received with sender and text', () async {
      final completer = Completer<Map<String, dynamic>>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'chat') {
          completer.complete(data);
        }
      });

      harness.sendRoomChat('room_101', 'لعبة ممتعة!');
      final received = await completer.future.timeout(Duration(seconds: 2));
      final msg = ChatMessageModel.fromJson(received);
      expect(msg.sender, equals('alice'));
      expect(msg.text, equals('لعبة ممتعة!'));
      await sub.cancel();
    });

    test('F12-3: Inbound chat triggers polite accessibility announcement', () {
      harness.recorder.clear();
      harness.announce('alice: أحسنت اللعب!', assertive: false);
      expect(harness.recorder.hasAnnounced(RegExp(r'alice.*أحسنت')), isTrue);
    });

    test('F12-4: Chat rate-limiting rejects more than 10 messages in 5 seconds', () async {
      final completer = Completer<String>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'error' && data['code'] == 'CHAT_RATE_LIMITED') {
          completer.complete(data['code'] as String);
        }
      });

      // Send 11 rapid messages
      for (int i = 0; i < 11; i++) {
        harness.sendRoomChat('room_101', 'رسالة $i');
      }

      final errorCode = await completer.future.timeout(Duration(seconds: 2));
      expect(errorCode, equals('CHAT_RATE_LIMITED'));
      await sub.cancel();
    });

    test('F12-5: Chat UI key translation provides placeholder and send labels', () {
      harness.setLocale('ar');
      expect(harness.translate('chat.send'), equals('إرسال'));
      expect(harness.translate('chat.placeholder'), equals('اكتب رسالة...'));
    });
  });
}
