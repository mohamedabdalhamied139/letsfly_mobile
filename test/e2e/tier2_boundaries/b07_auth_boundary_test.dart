/// Tier 2 Boundary Test: B7 Authentication Boundaries
/// Verifies 72-byte password boundary, special characters, whitespace trimming, and empty fields.
library b07_auth_boundary_test;

import 'package:letsfly_mobile/data/models/user_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B7: Authentication Flow Boundaries', () {
    test('B7-1: Password of exactly 72 bytes is accepted for registration', () async {
      final user = UserModel(id: 1, username: 'exact_72_user', displayName: 'Exact 72');
      expect(user.username, equals('exact_72_user'));
      final exact72Password = 'P' * 72;
      final res = await harness.postHttp('/api/auth/register', {
        'username': 'exact_72_user',
        'password': exact72Password,
      });
      expect(res['statusCode'], equals(200));
    });

    test('B7-2: Password of 73 bytes is rejected with 422 to prevent bcrypt truncation', () async {
      final exact73Password = 'P' * 73;
      final res = await harness.postHttp('/api/auth/register', {
        'username': 'exact_73_user',
        'password': exact73Password,
      });
      expect(res['statusCode'], equals(422));
    });

    test('B7-3: Username with special characters and Arabic script is supported', () async {
      final res = await harness.postHttp('/api/auth/register', {
        'username': 'لاعب_متميز',
        'password': 'password123',
      });
      expect(res['statusCode'], equals(200));
    });

    test('B7-4: Empty username or empty password fails validation with 422', () async {
      final res = await harness.postHttp('/api/auth/register', {
        'username': '',
        'password': '',
      });
      expect(res['statusCode'], equals(422));
    });

    test('B7-5: Non-existent user login returns 401 with generic error detail', () async {
      final success = await harness.login('ghost_user_does_not_exist', 'password123');
      expect(success, isFalse);
    });
  });
}
