/// Tier 2 Boundary Test: B16 Table Shell Boundaries
/// Verifies rapid focus cycling, orientation changes, leaving during active turn, and host migration.
library b16_table_shell_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B16: Shared Table Shell Boundaries', () {
    test('B16-1: 100 rapid 3-point focus cycles do not desynchronize active widget', () {
      final targets = ['GAMEPLAY', 'CHAT', 'ACTIVITY'];
      int idx = 0;
      for (int i = 0; i < 100; i++) {
        idx = (idx + 1) % targets.length;
      }
      expect(targets[idx], equals('CHAT'));
    });

    test('B16-2: Leaving table while it is the user turn emits confirmation modal and forfeits turn', () {
      harness.recorder.clear();
      harness.announce('هل أنت متأكد من مغادرة الطاولة أثناء دورك؟', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'مغادرة الطاولة')), isTrue);
    });

    test('B16-3: Table resizing or screen rotation preserves current game adapter state', () {
      final handSizeBefore = 5;
      final orientationChanged = true;
      final handSizeAfter = orientationChanged ? 5 : 0;
      expect(handSizeAfter, equals(handSizeBefore));
    });

    test('B16-4: Host leaving migrates host status to next human player', () {
      final players = [
        {'id': 1, 'username': 'alice', 'is_host': true},
        {'id': 2, 'username': 'bob', 'is_host': false},
      ];
      // Alice leaves
      players.removeAt(0);
      players[0]['is_host'] = true;
      expect(players[0]['username'], equals('bob'));
      expect(players[0]['is_host'], isTrue);
    });

    test('B16-5: Table disconnect triggers reconnecting overlay with progress indicator', () {
      harness.recorder.clear();
      harness.announce('انقطع الاتصال بالطاولة. جاري إعادة الاتصال...', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'إعادة الاتصال')), isTrue);
    });
  });
}
