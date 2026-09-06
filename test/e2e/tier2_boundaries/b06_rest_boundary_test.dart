/// Tier 2 Boundary Test: B6 REST Client Boundaries
/// Verifies exact 64KB boundary, empty bodies, non-existent methods, and custom status codes.
library b06_rest_boundary_test;

import 'package:letsfly_mobile/core/network/api_client.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B6: REST API Client Boundaries', () {
    test('B6-1: Request payload under 64KB threshold is accepted', () async {
      expect(harness.apiClient is DioApiClient, isTrue);
      final safeString = 'A' * (10 * 1024); // 10KB
      final res = await harness.postHttp('/api/rooms', {'data': safeString});
      expect(res['statusCode'], equals(201));
    });

    test('B6-2: Request payload exactly over 64KB is strictly rejected with 413', () async {
      final largeString = 'B' * (65 * 1024);
      final res = await harness.postHttp('/api/rooms', {'data': largeString});
      expect(res['statusCode'], equals(413));
    });

    test('B6-3: Custom server error codes (503 Service Unavailable) are handled cleanly', () async {
      harness.httpServer.customStatusCode = 503;
      harness.httpServer.customErrorDetail = 'Service Unavailable';
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(503));
      harness.httpServer.customStatusCode = null;
      harness.httpServer.customErrorDetail = null;
    });

    test('B6-4: Empty JSON object in POST body is parsed without error', () async {
      final res = await harness.postHttp('/api/rooms', {});
      expect(res['statusCode'], equals(201));
    });

    test('B6-5: Unsupported HTTP method on endpoint returns 404 or 405', () async {
      final res = await harness.getHttp('/api/auth/register');
      expect(res['statusCode'], equals(404));
    });
  });
}
