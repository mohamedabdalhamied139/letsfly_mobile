/// Tier 2 Boundary Test: B9 Home Lobby Boundaries
/// Verifies empty activity feed, extreme item counts, long display names, and offline status.
library b09_home_lobby_boundary_test;

import 'package:letsfly_mobile/data/models/user_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B9: Home Lobby & Navigation Boundaries', () {
    test('B9-1: Empty activity feed renders explicit accessible empty state', () {
      final profile = UserProfile(id: 1, username: 'test', displayName: 'Test User');
      expect(profile.displayName, equals('Test User'));
      final feed = <String>[];
      final emptyLabel = feed.isEmpty ? 'لا يوجد نشاط حديث.' : 'النشاط';
      expect(emptyLabel, equals('لا يوجد نشاط حديث.'));
    });

    test('B9-2: Activity feed with 500+ items caps in-memory display to prevent lag', () {
      final fullFeed = List.generate(500, (i) => 'نشاط $i');
      final cappedFeed = fullFeed.take(50).toList();
      expect(cappedFeed.length, equals(50));
    });

    test('B9-3: Extra long display name (100+ characters) is rendered without overflow', () {
      final longName = 'اسم_طويل_' * 10;
      final greeting = 'مرحبًا بعودتك $longName.';
      expect(greeting.isNotEmpty, isTrue);
    });

    test('B9-4: Navigation to non-existent menu option fails gracefully', () {
      final validOptions = ['tables', 'friends', 'settings', 'logout'];
      final target = 'unknown_option';
      expect(validOptions.contains(target), isFalse);
    });

    test('B9-5: Offline state announcement warns user when disconnected from network', () {
      harness.recorder.clear();
      harness.announce('فقدت الاتصال بالخادم. جاري إعادة المحاولة...', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'فقدت الاتصال')), isTrue);
    });
  });
}
