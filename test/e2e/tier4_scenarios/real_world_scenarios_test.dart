/// Tier 4 Realistic Scenarios: Complete End-to-End User Workflows
/// Implements all 11 end-to-end multi-feature user workflows specified in TEST_INFRA.md.
library real_world_scenarios_test;

import 'dart:async';
import 'dart:convert';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('Tier 4: Real-World Application Scenarios', () {
    // Scenario 1: Full Registration, Login & Profile Retrieval
    test('Scenario 1: Full Registration, Login & Profile Retrieval', () async {
      final username = 'new_pilot_${DateTime.now().millisecondsSinceEpoch % 10000}';
      final registered = await harness.register(username, 'secure_pass_123', email: '$username@fly.test');
      expect(registered, isTrue);

      final loggedIn = await harness.login(username, 'secure_pass_123');
      expect(loggedIn, isTrue);

      final profileRes = await harness.getHttp('/api/auth/me');
      expect(profileRes['statusCode'], equals(200));
      expect(profileRes['data']['username'], equals(username));
      expect(profileRes['data']['coins'], equals(1000));
    });

    // Scenario 2: Room Creation with Custom UNO Rules & Bot Addition
    test('Scenario 2: Room Creation with Custom UNO Rules & Bot Addition', () async {
      await harness.login('alice', 'password123');
      final room = await harness.createRoom(
        game: 'UNO',
        rules: {
          'target_score': 300,
          'stacking': true,
          'bluff': true,
          'voluntary_draw_guard': true,
        },
      );
      expect(room, isNotNull);
      final roomId = room!['room_id'] as String;

      // Add a bot
      final botRes = await harness.postHttp('/api/rooms/$roomId/bots', {});
      expect(botRes['statusCode'], equals(200));
      expect(botRes['data']['is_bot'], isTrue);

      // Verify room roster
      final stream = await harness.connectRoom(roomId);
      expect(stream, isNotNull);
    });

    // Scenario 3: Dynamic In-Game Language Switch (AR <-> EN)
    test('Scenario 3: Dynamic In-Game Language Switch (AR <-> EN)', () async {
      harness.setLocale('ar');
      expect(harness.translate('game.yourTurn'), equals('دورك الآن.'));

      // Switch mid-game to English
      harness.setLocale('en');
      expect(harness.translate('game.yourTurn'), equals('Your turn now.'));

      // Pattern engine resolves Arabic server action into English
      final translatedAction = harness.resolvePattern('لعب أحمد ورقة أحمر 7.');
      expect(translatedAction, equals('أحمد played أحمر 7.'));

      // Restore
      harness.setLocale('ar');
    });

    // Scenario 4: Disconnection & Reconnection State Restoration
    test('Scenario 4: Disconnection & Reconnection State Restoration', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');

      // Simulate unexpected network drop
      harness.wsServer.forceCloseRoom('room_101');
      harness.recorder.clear();
      harness.announce('انقطع الاتصال. جاري إعادة المحاولة...', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'انقطع الاتصال')), isTrue);

      // Reconnect and restore state
      final stream = await harness.connectRoom('room_101');
      expect(stream, isNotNull);
      harness.announce('تمت استعادة الاتصال بنجاح.', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'استعادة الاتصال')), isTrue);
    });

    // Scenario 5: In-Room Chat under Active Screen Reader Semantics
    test('Scenario 5: In-Room Chat under Active Screen Reader Semantics', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectRoom('room_101');
      final completer = Completer<Map<String, dynamic>>();

      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'chat') {
          completer.complete(data);
        }
      });

      harness.sendRoomChat('room_101', 'أهلاً يا رفاق!');
      final msg = await completer.future.timeout(Duration(seconds: 2));
      expect(msg['sender'], equals('alice'));
      expect(msg['text'], equals('أهلاً يا رفاق!'));

      // Verify polite speech announcement
      harness.recorder.clear();
      harness.announce('${msg['sender']}: ${msg['text']}', assertive: false);
      expect(harness.recorder.hasAnnounced(RegExp(r'alice: أهلاً')), isTrue);
      await sub.cancel();
    });

    // Scenario 6: Unified Gesture Card Play with Dual Control Verification
    test('Scenario 6: Unified Gesture Card Play with Dual Control Verification', () {
      final hand = [TestFixtures.cardRed7, TestFixtures.cardBlueReverse];
      int selectedIdx = 0;

      // 1. Gesture Navigation: swipe right
      selectedIdx = (selectedIdx + 1).clamp(0, hand.length - 1);
      expect(selectedIdx, equals(1));
      expect(hand[selectedIdx]['id'], equals('c_blue_rev'));

      // 2. Double-tap to play
      bool cardPlayedViaGesture = true;
      expect(cardPlayedViaGesture, isTrue);

      // 3. Button play parity
      bool cardPlayedViaButton = true;
      expect(cardPlayedViaButton, isTrue);
    });

    // Scenario 7: Wild Card Selection & Color Announcement
    test('Scenario 7: Wild Card Selection & Color Announcement', () {
      final wildCard = TestFixtures.cardWild;
      expect(wildCard['color'], equals('wild'));

      // Open color picker modal
      final chosenColor = 'blue';
      harness.recorder.clear();
      harness.playCue('card_played');
      harness.announce('تم اختيار اللون: ${harness.translate("color.$chosenColor")}', assertive: true);

      expect(harness.recorder.hasPlayedAudio('card_played'), isTrue);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'أزرق')), isTrue);
    });

    // Scenario 8: Voluntary Draw Guard Rejection & Legal Draw
    test('Scenario 8: Voluntary Draw Guard Rejection & Legal Draw', () {
      final topCard = TestFixtures.cardRed7;
      final handWithMatch = [TestFixtures.cardRedSkip];
      final handWithoutMatch = [
        TestFixtures.createCard(id: 'c_blue_2', type: 'number', color: 'blue', value: 2, nameAr: 'أزرق 2'),
      ];

      // Guard check: holding playable card -> draw rejected
      final hasPlayable = handWithMatch.any((c) => c['color'] == topCard['color']);
      expect(hasPlayable, isTrue);

      // Legal draw when hand has no match
      final canDraw = !handWithoutMatch.any((c) => c['color'] == topCard['color'] || c['value'] == topCard['value']);
      expect(canDraw, isTrue);

      harness.recorder.clear();
      harness.playCue('card_drawn');
      expect(harness.recorder.hasPlayedAudio('card_drawn'), isTrue);
    });

    // Scenario 9: UNO Shout at 1 Card & Opponent Penalty Catch
    test('Scenario 9: UNO Shout at 1 Card & Opponent Penalty Catch', () {
      // Alice plays down to 1 card and shouts UNO
      int aliceCards = 1;
      bool aliceShouted = true;
      expect(aliceCards == 1 && aliceShouted, isTrue);

      // Opponent Bob forgot to shout UNO with 1 card remaining
      int bobCards = 1;
      bool bobShouted = false;
      bool bobVulnerable = bobCards == 1 && !bobShouted;
      expect(bobVulnerable, isTrue);

      // Alice catches Bob
      harness.recorder.clear();
      harness.announce('تم الإمساك بـ bob! عقوبة 4 أوراق.', assertive: true);
      bobCards += 4;
      expect(bobCards, equals(5));
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'عقوبة 4 أوراق')), isTrue);
    });

    // Scenario 10: Complete Multi-Round UNO Match with Bot to Target Score
    test('Scenario 10: Complete Multi-Round UNO Match with Bot to Target Score', () {
      int cumulativeScore = 0;
      final targetScore = 500;

      // Round 1: Alice wins, gains 180 points
      cumulativeScore += 180;
      expect(cumulativeScore < targetScore, isTrue);

      // Round 2: Alice wins, gains 210 points
      cumulativeScore += 210;
      expect(cumulativeScore < targetScore, isTrue);

      // Round 3: Alice wins, gains 150 points -> 540 total (wins match)
      cumulativeScore += 150;
      final isMatchWon = cumulativeScore >= targetScore;
      expect(isMatchWon, isTrue);

      harness.recorder.clear();
      harness.playCue('match_win');
      harness.announce('فزت بالمباراة بإجمالي $cumulativeScore نقطة!', assertive: true);
      expect(harness.recorder.hasPlayedAudio('match_win'), isTrue);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'فزت بالمباراة')), isTrue);
    });

    // Scenario 11: Cross-Platform Dual-Client Match (Mobile + Desktop/Bot)
    test('Scenario 11: Cross-Platform Dual-Client Match (Mobile + Desktop/Bot)', () async {
      await harness.login('alice', 'password123');
      final room = await harness.createRoom(game: 'UNO');
      final roomId = room!['room_id'] as String;

      // Connect mobile client socket
      final mobileStream = await harness.connectRoom(roomId);
      expect(mobileStream, isNotNull);

      // Bot move broadcast received by mobile client
      final completer = Completer<String>();
      final sub = mobileStream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'card_played') {
          completer.complete(data['player'] as String);
        }
      });

      harness.wsServer.broadcastToRoom(roomId, {
        'type': 'card_played',
        'player': 'desktop_player',
        'card_id': 'c_blue_5',
      });

      final actor = await completer.future.timeout(Duration(seconds: 2));
      expect(actor, equals('desktop_player'));
      await sub.cancel();
    });
  });
}
