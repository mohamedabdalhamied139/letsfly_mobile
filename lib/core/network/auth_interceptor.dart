import 'package:dio/dio.dart';

/// Interceptor that attaches the Bearer JWT token to outgoing HTTP requests.
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() tokenProvider;

  AuthInterceptor({required this.tokenProvider});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token injection for login and registration endpoints
    if (options.path.contains('/login') || options.path.contains('/register')) {
      return handler.next(options);
    }

    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }
}
