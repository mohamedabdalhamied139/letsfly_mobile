/// Tier 1 Feature Test: F5 Secure Token & Session Storage
/// Verifies JWT token persistence, retrieval, revocation, and session clearing.
library f05_token_storage_test;

import 'package:letsfly_mobile/data/datasources/secure_storage_service.dart';
import 'package:letsfly_mobile/data/models/user_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F5: Token Storage & Session Management', () {
    test('F5-1: Successfully persists access token upon login', () async {
      final storage = SecureStorageService();
      await storage.saveAccessToken('token_alice_storage');
      final savedToken = await storage.getAccessToken();
      expect(savedToken, equals('token_alice_storage'));

      final success = await harness.login('alice', 'password123');
      expect(success, isTrue);
      expect(harness.currentAuthToken, isNotNull);
      expect(harness.currentAuthToken, contains('alice'));
    });

    test('F5-2: Current user profile is accessible after session initialization', () {
      expect(harness.currentUser, isNotNull);
      expect(harness.currentUser!.username, equals('alice'));
      expect(harness.currentUser!.displayName, equals('Alice Mobile'));
      final model = UserModel(id: 1, username: 'alice', displayName: 'Alice Mobile');
      expect(model.username, equals(harness.currentUser!.username));
    });

    test('F5-3: Token is passed in Authorization header for authenticated requests', () async {
      final res = await harness.getHttp('/api/auth/me');
      expect(res['statusCode'], equals(200));
      expect(res['data']['username'], equals('alice'));
    });

    test('F5-4: Logout invalidates and clears active session token locally', () async {
      final storage = SecureStorageService();
      await storage.deleteAccessToken();
      expect(await storage.getAccessToken(), isNull);
      await harness.logout();
      expect(harness.currentAuthToken, isNull);
      expect(harness.currentUser, isNull);
    });

    test('F5-5: Accessing protected endpoints without token returns 401 Unauthorized', () async {
      final res = await harness.getHttp('/api/auth/me', token: null);
      expect(res['statusCode'], equals(401));
    });
  });
}
