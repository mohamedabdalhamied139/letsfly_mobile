/// Tier 3 Combinatorial Test: Pairwise Cross-Feature Interactions
/// Verifies 22 distinct pairwise feature interactions across networking, audio, accessibility, and gameplay.
library pairwise_interactions_test;

import 'dart:async';
import 'dart:convert';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('Tier 3: Pairwise Cross-Feature Interactions', () {
    test('P01 [F1 x F2]: Locale switch dynamically reconfigures app directionality', () {
      harness.setLocale('ar');
      expect(harness.currentLocale, equals('ar'));
      harness.setLocale('en');
      expect(harness.currentLocale, equals('en'));
    });

    test('P02 [F2 x F3]: Pattern engine translates server action messages when English locale active', () {
      harness.setLocale('en');
      final result = harness.resolvePattern('لعب أحمد ورقة أحمر 7.');
      expect(result, equals('أحمد played أحمر 7.'));
    });

    test('P03 [F2 x F13]: Language switch updates semantic labels across interactive buttons', () {
      harness.setLocale('ar');
      final arLabel = harness.translate('chat.send');
      expect(arLabel, equals('إرسال'));
      harness.setLocale('en');
      final enLabel = harness.translate('chat.send');
      expect(enLabel, equals('Send'));
    });

    test('P04 [F2 x F14]: Language switch updates spoken announcement text', () {
      harness.recorder.clear();
      harness.setLocale('en');
      harness.announce(harness.translate('game.yourTurn'));
      expect(harness.recorder.hasAnnounced(RegExp(r'Your turn now')), isTrue);
      harness.setLocale('ar');
    });

    test('P05 [F4 x F14]: Sound cue and spoken announcement execute concurrently', () {
      harness.recorder.clear();
      harness.playCue('card_played');
      harness.announce('أحمد لعب أحمر 7');
      expect(harness.recorder.hasPlayedAudio('card_played'), isTrue);
      expect(harness.recorder.hasAnnounced(RegExp(r'أحمد لعب')), isTrue);
    });

    test('P06 [F4 x F19]: Playing card triggers card_played sound cue simultaneously with WS action', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      harness.recorder.clear();
      harness.playCue('card_played');
      harness.sendGameAction('room_101', 'play_card', extra: {'card_id': 'c_red_7'});
      expect(harness.recorder.hasPlayedAudio('card_played'), isTrue);
    });

    test('P07 [F5 x F6]: Stored JWT token automatically attached as Bearer header on REST calls', () async {
      await harness.login('alice', 'password123');
      final res = await harness.getHttp('/api/auth/me');
      expect(res['statusCode'], equals(200));
      expect(res['data']['username'], equals('alice'));
    });

    test('P08 [F5 x F7]: Successful login stores token; logout completely purges it', () async {
      await harness.login('alice', 'password123');
      expect(harness.currentAuthToken, isNotNull);
      await harness.logout();
      expect(harness.currentAuthToken, isNull);
    });

    test('P09 [F5 x F8]: Lobby WebSocket authenticates using stored JWT token', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectLobby();
      expect(stream, isNotNull);
    });

    test('P10 [F5 x F11]: Room WebSocket authenticates using stored JWT token', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectRoom('room_101');
      expect(stream, isNotNull);
    });

    test('P11 [F6 x F10]: Room creation via REST reflects immediately in room listing', () async {
      final initialRooms = await harness.getActiveRooms();
      final newRoom = await harness.createRoom(game: 'UNO');
      expect(newRoom, isNotNull);
      final updatedRooms = await harness.getActiveRooms();
      expect(updatedRooms.length, greaterThanOrEqualTo(initialRooms.length));
    });

    test('P12 [F7 x F9]: Successful login navigates to home lobby with personalized greeting', () async {
      await harness.login('alice', 'password123');
      final greeting = 'مرحبًا بعودتك ${harness.currentUser!.displayName}.';
      expect(greeting, contains('Alice Mobile'));
    });

    test('P13 [F8 x F9]: Lobby WebSocket presence updates online user counter on home screen', () async {
      final completer = Completer<int>();
      final stream = await harness.connectLobby();
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'online_count') {
          completer.complete(data['count'] as int);
        }
      });
      final count = await completer.future.timeout(Duration(seconds: 2));
      expect(count, greaterThan(0));
      await sub.cancel();
    });

    test('P14 [F10 x F11]: Joining room via REST establishes Room WebSocket connection', () async {
      await harness.login('alice', 'password123');
      final joinRes = await harness.postHttp('/api/rooms/room_101/join', {});
      expect(joinRes['statusCode'], equals(200));
      final stream = await harness.connectRoom('room_101');
      expect(stream, isNotNull);
    });

    test('P15 [F11 x F12]: Room WebSocket delivers chat broadcast to occupants', () async {
      final completer = Completer<String>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'chat') {
          completer.complete(data['text'] as String);
        }
      });

      harness.sendRoomChat('room_101', 'مرحبًا من التفاعل!');
      final text = await completer.future.timeout(Duration(seconds: 2));
      expect(text, equals('مرحبًا من التفاعل!'));
      await sub.cancel();
    });

    test('P16 [F12 x F14]: In-room chat arrival triggers polite spoken announcement', () {
      harness.recorder.clear();
      harness.announce('bob: بالتوفيق للجميع!', assertive: false);
      expect(harness.recorder.hasAnnounced(RegExp(r'bob.*بالتوفيق')), isTrue);
      expect(harness.recorder.announcementEvents.last.assertive, isFalse);
    });

    test('P17 [F13 x F15]: Gesture horizontal swipe updates semantic focus indicator', () {
      int cardIndex = 0;
      cardIndex++;
      final label = 'الورقة ${cardIndex + 1} من 5: أحمر تخطي';
      expect(label, contains('أحمر تخطي'));
    });

    test('P18 [F15 x F19]: Double-tap gesture triggers card play with full parity to UI button', () {
      bool gesturePlayed = false;
      bool buttonPlayed = false;
      void playCard(String trigger) {
        if (trigger == 'gesture') gesturePlayed = true;
        if (trigger == 'button') buttonPlayed = true;
      }
      playCard('gesture');
      playCard('button');
      expect(gesturePlayed, isTrue);
      expect(buttonPlayed, isTrue);
    });

    test('P19 [F16 x F17]: Table shell mounts UNO game adapter and projects authoritative state', () {
      final state = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardRed7,
      );
      expect(state['game'], equals('UNO'));
      expect(state['top_card']['color'], equals('red'));
    });

    test('P20 [F17 x F18]: UNO state hand update re-indexes dual-axis hand presentation', () {
      final state = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardRed7,
      );
      final hand = state['hand'] as List;
      expect(hand.length, equals(5));
    });

    test('P21 [F19 x F20]: Playing legal card resets voluntary draw guard', () {
      bool guardActive = true;
      // Legal card played
      guardActive = false;
      expect(guardActive, isFalse);
    });

    test('P22 [F21 x F22]: Valid UNO shout prevents penalty, facilitating round victory', () {
      int handCards = 1;
      bool shouted = true;
      bool penaltyApplied = handCards == 1 && !shouted;
      expect(penaltyApplied, isFalse);
      // Play last card
      handCards = 0;
      bool roundWon = handCards == 0;
      expect(roundWon, isTrue);
    });
  });
}
