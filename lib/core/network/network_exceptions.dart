/// Structured network exception hierarchy for Let's Fly.
abstract class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NetworkException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ServerException extends NetworkException {
  final dynamic data;

  const ServerException(
    super.message, {
    super.statusCode,
    this.data,
  });
}

class BadRequestException extends NetworkException {
  final dynamic data;

  const BadRequestException([
    String message = 'طلب غير صالح.',
    this.data,
  ]) : super(message, statusCode: 400);
}

class InvalidCredentialsException extends BadRequestException {
  const InvalidCredentialsException([
    String message = 'اسم المستخدم أو كلمة المرور غير صحيحة.',
  ]) : super(message);
}

class ValidationException extends NetworkException {
  final List<String> errors;
  final dynamic rawErrors;

  const ValidationException(
    super.message, {
    this.errors = const [],
    this.rawErrors,
  }) : super(statusCode: 422);
}

class UnauthorizedException extends NetworkException {
  const UnauthorizedException([
    String message = 'انتهت الجلسة أو يجب تسجيل الدخول',
  ]) : super(message, statusCode: 401);
}

class ForbiddenException extends NetworkException {
  const ForbiddenException([
    String message = 'ليس لديك صلاحية للقيام بهذا الإجراء',
  ]) : super(message, statusCode: 403);
}

class ConflictException extends NetworkException {
  const ConflictException([String message = 'تعارض في حالة الطلب. حاول مرة أخرى.']) : super(message, statusCode: 409);
}

class NotFoundException extends NetworkException {
  const NotFoundException([
    String message = 'العنصر أو الصفحة المطلوبة غير موجودة',
  ]) : super(message, statusCode: 404);
}

class ConnectionException extends NetworkException {
  const ConnectionException([
    String message = 'فشل الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت',
  ]) : super(message);
}

class RateLimitException extends NetworkException {
  final int? retryAfterSeconds;

  const RateLimitException([
    String message = 'تم تجاوز حد الطلبات المسموح به. يرجى الانتظار والمحاولة لاحقًا.',
    this.retryAfterSeconds,
  ]) : super(message, statusCode: 429);
}

class WebSocketException extends NetworkException {
  final int? closeCode;
  final String? closeReason;

  const WebSocketException(
    super.message, {
    this.closeCode,
    this.closeReason,
  });

  @override
  String toString() =>
      'WebSocketException: $message (code: $closeCode, reason: $closeReason)';
}
