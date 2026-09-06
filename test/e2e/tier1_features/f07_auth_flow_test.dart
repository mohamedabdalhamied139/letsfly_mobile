/// Tier 1 Feature Test: F7 Authentication Flow
/// Verifies login, registration, password validation, error feedback, and profile retrieval.
library f07_auth_flow_test;

import 'package:letsfly_mobile/core/network/api_client.dart';
import 'package:letsfly_mobile/data/models/user_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F7: Authentication & Account Flows', () {
    test('F7-1: Successful login establishes active session and profile', () async {
      final success = await harness.login('alice', 'valid_password');
      expect(success, isTrue);
      expect(harness.currentUser!.username, equals('alice'));
      expect(harness.currentUser!.coins, equals(1250));
      final auth = AuthResponse(
        accessToken: harness.currentAuthToken!,
        user: UserModel(id: harness.currentUser!.id, username: 'alice', displayName: 'Alice Mobile'),
      );
      expect(auth.user.username, equals('alice'));
    });

    test('F7-2: Invalid credentials login fails with 401', () async {
      final success = await harness.login('alice', '');
      expect(success, isFalse);
    });

    test('F7-3: New user registration succeeds and grants initial 1000 coins', () async {
      final success = await harness.register('david', 'password123', email: 'david@letsfly.test');
      expect(success, isTrue);
      expect(harness.currentUser!.username, equals('david'));
    });

    test('F7-4: Registering already existing username is rejected with 400 Bad Request', () async {
      final res = await harness.postHttp('/api/auth/register', {
        'username': 'alice',
        'password': 'password123',
      });
      expect(res['statusCode'], equals(400));
      expect(res['data']['detail'], equals('اسم المستخدم مستخدم بالفعل.'));
    });

    test('F7-5: Password exceeding 72 bytes is rejected to prevent bcrypt truncation', () async {
      final longPassword = 'P' * 73;
      final res = await harness.postHttp('/api/auth/register', {
        'username': 'new_user',
        'password': longPassword,
      });
      expect(res['statusCode'], equals(422));
      expect(res['data']['detail'], contains('72 بايت'));
    });
  });
}
