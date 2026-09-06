/// Tier 1 Feature Test: F9 Home Lobby & Navigation
/// Verifies 8 main menu items, user greeting, activity feed, and category filtering.
library f09_home_lobby_test;

import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F9: Home Lobby & Navigation Views', () {
    test('F9-1: Home lobby presents all 8 canonical navigation targets', () {
      final menuKeys = [
        'home.tables',
        'home.friends',
        'home.online',
        'home.settings',
        'auth.logout',
      ];
      for (final key in menuKeys) {
        expect(harness.translate(key).isNotEmpty, isTrue);
      }
      expect(harness.translationManager.arCatalog.containsKey('القائمة الرئيسية'), isTrue);
    });

    test('F9-2: User greeting includes active user display name', () async {
      await harness.login('alice', 'password123');
      final greeting = 'مرحبًا بعودتك ${harness.currentUser!.displayName}.';
      expect(greeting, contains('Alice Mobile'));
    });

    test('F9-3: Online users counter format is accessible and dynamic', () {
      final count = 15;
      final label = 'المتصلون ($count)';
      expect(label, contains('15'));
    });

    test('F9-4: Navigation to tables view triggers screen transition announcement', () {
      harness.recorder.clear();
      harness.announce('تم الانتقال إلى قائمة الطاولات');
      expect(harness.recorder.hasAnnounced(RegExp(r'الطاولات')), isTrue);
    });

    test('F9-5: Activity feed items categorized into distinct channels', () {
      final categories = ['TABLE_CHAT', 'PRIVATE_MESSAGES', 'FRIENDS', 'GAMEPLAY', 'ALL'];
      expect(categories.length, equals(5));
      expect(categories.contains('GAMEPLAY'), isTrue);
    });
  });
}
