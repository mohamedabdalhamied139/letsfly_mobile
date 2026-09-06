/// Tier 2 Boundary Test: B5 Secure Token Storage Boundaries
/// Verifies corrupted tokens, expired timestamps, empty tokens, and session race conditions.
library b05_storage_boundary_test;

import 'package:letsfly_mobile/data/datasources/secure_storage_service.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B5: Token Storage & Session Boundaries', () {
    test('B5-1: Empty token string in authorization header returns 401', () async {
      final storage = SecureStorageService();
      await storage.deleteAccessToken();
      expect(await storage.getAccessToken(), isNull);
      final res = await harness.getHttp('/api/auth/me', token: '');
      expect(res['statusCode'], equals(401));
    });

    test('B5-2: Corrupted or tampered token returns 401 Unauthorized', () async {
      final res = await harness.getHttp('/api/auth/me', token: 'gibberish.corrupted.token');
      expect(res['statusCode'], equals(401));
    });

    test('B5-3: Token with expired version after logout returns 401 on subsequent calls', () async {
      await harness.login('alice', 'password123');
      final oldToken = harness.currentAuthToken;
      await harness.logout();

      final res = await harness.getHttp('/api/auth/me', token: oldToken);
      expect(res['statusCode'], equals(401));
    });

    test('B5-4: Whitespace-only token is rejected with 401', () async {
      final res = await harness.getHttp('/api/auth/me', token: '   ');
      expect(res['statusCode'], equals(401));
    });

    test('B5-5: Multiple consecutive logouts do not fail or corrupt state', () async {
      await harness.logout();
      await harness.logout();
      expect(harness.currentAuthToken, isNull);
    });
  });
}
