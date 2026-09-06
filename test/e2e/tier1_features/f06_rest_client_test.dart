/// Tier 1 Feature Test: F6 REST API Client & Error Handling
/// Verifies HTTP client operations, error mapping, rate-limiting, and payload size guard.
library f06_rest_client_test;

import 'package:letsfly_mobile/core/network/api_client.dart';
import 'package:letsfly_mobile/core/network/network_exceptions.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F6: REST API Client & Error Handling', () {
    test('F6-1: Successful GET request parses JSON payload', () async {
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(200));
      expect(res['data'] is List, isTrue);
      final clientRes = await harness.apiClient.get<dynamic>('/api/rooms');
      expect(clientRes.statusCode, equals(200));
      expect(clientRes.data is List, isTrue);
    });

    test('F6-2: Non-existent endpoint returns 404 Not Found with Arabic detail', () async {
      final res = await harness.getHttp('/api/non_existent_route');
      expect(res['statusCode'], equals(404));
      expect(res['data']['detail'], equals('المسار غير موجود.'));
      bool threwNotFound = false;
      try {
        await harness.apiClient.get<dynamic>('/api/non_existent_route');
      } on NotFoundException {
        threwNotFound = true;
      }
      expect(threwNotFound, isTrue);
    });

    test('F6-3: Server 500 internal error triggers error handler', () async {
      harness.httpServer.simulate500Error = true;
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(500));
      expect(res['data']['detail'], equals('Internal Server Error'));
      bool threwServer = false;
      try {
        await harness.apiClient.get<dynamic>('/api/rooms');
      } on ServerException {
        threwServer = true;
      }
      expect(threwServer, isTrue);
      harness.httpServer.simulate500Error = false;
    });

    test('F6-4: Rate-limit 429 response is handled correctly', () async {
      harness.httpServer.simulateRateLimit429 = true;
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(429));
      expect(res['data']['detail'], equals('Too Many Requests'));
      bool threwRateLimit = false;
      try {
        await harness.apiClient.get<dynamic>('/api/rooms');
      } on RateLimitException {
        threwRateLimit = true;
      }
      expect(threwRateLimit, isTrue);
      harness.httpServer.simulateRateLimit429 = false;
    });

    test('F6-5: Request payload exceeding 64KB is rejected with 413 Payload Too Large', () async {
      final hugeString = 'A' * (65 * 1024);
      final res = await harness.postHttp('/api/rooms', {'huge_data': hugeString});
      expect(res['statusCode'], equals(413));
      expect(res['data']['detail'], equals('حجم الطلب كبير جدًا.'));
    });
  });
}
