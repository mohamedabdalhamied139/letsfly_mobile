import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';

import 'network_exceptions.dart';

import '../../data/models/room_model.dart';

import '../../data/models/user_model.dart';



export 'network_exceptions.dart';

export '../../data/models/room_model.dart' show RoomModel, RoomSummary;

export '../../data/models/user_model.dart' show UserModel, UserProfile, AuthResponse;



/// Base API client interface for HTTP and domain operations.

abstract class ApiClient {

  // --- Domain Interface Contracts (PROJECT.md lines 67-70) ---

  Future<AuthResponse> login(String username, String password);

  Future<UserProfile> getProfile(String userId);

  Future<List<RoomSummary>> getRooms();



  // --- Generic HTTP Operations ---

  Future<Response<T>> get<T>(

    String path, {

    Map<String, dynamic>? queryParameters,

    Options? options,

  });



  Future<Response<T>> post<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  });



  Future<Response<T>> put<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  });



  Future<Response<T>> delete<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  });

}



/// Dio-based production implementation of ApiClient.

class DioApiClient implements ApiClient {

  final Dio _dio;



  DioApiClient({

    String baseUrl = ApiEndpoints.defaultHttpHost,

    Dio? dio,

    List<Interceptor>? interceptors,

  }) : _dio = dio ??

            Dio(

              BaseOptions(

                baseUrl: baseUrl,

                connectTimeout: const Duration(seconds: 10),

                receiveTimeout: const Duration(seconds: 10),

                sendTimeout: const Duration(seconds: 10),

                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                },

              ),

            ) {

    if (interceptors != null) {

      _dio.interceptors.addAll(interceptors);

    }

  }



  Dio get dioInstance => _dio;



  // ==========================================

  // Domain Interface Implementations

  // ==========================================



  @override

  Future<AuthResponse> login(String username, String password) async {

    final response = await post<dynamic>(

      ApiEndpoints.login,

      data: {

        'username': username.trim(),

        'password': password,

      },

    );

    final data = response.data;

    if (data is Map<String, dynamic>) {

      return AuthResponse.fromJson(data);

    }

    throw const ServerException('استجابة غير صالحة من خادم المصادقة');

  }



  @override

  Future<UserProfile> getProfile(String userId) async {

    final trimmed = userId.trim();

    final path = trimmed.toLowerCase() == 'me'

        ? ApiEndpoints.me

        : '/api/users/$trimmed/profile';

    final response = await get<dynamic>(path);

    final data = response.data;

    if (data is Map<String, dynamic>) {

      return UserProfile.fromJson(data);

    }

    throw const ServerException('استجابة غير صالحة من خادم الملف الشخصي');

  }



  @override

  Future<List<RoomSummary>> getRooms() async {

    final response = await get<dynamic>(ApiEndpoints.rooms);

    final data = response.data;

    if (data is List) {

      return data

          .whereType<Map<String, dynamic>>()

          .map((json) => RoomModel.fromJson(json))

          .toList();

    }

    return [];

  }



  // ==========================================

  // Generic HTTP Primitives

  // ==========================================



  @override

  Future<Response<T>> get<T>(

    String path, {

    Map<String, dynamic>? queryParameters,

    Options? options,

  }) async {

    try {

      return await _dio.get<T>(path, queryParameters: queryParameters, options: options);

    } on DioException catch (e) {

      throw _handleDioError(e);

    }

  }



  @override

  Future<Response<T>> post<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  }) async {

    try {

      return await _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

    } on DioException catch (e) {

      throw _handleDioError(e);

    }

  }



  @override

  Future<Response<T>> put<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  }) async {

    try {

      return await _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);

    } on DioException catch (e) {

      throw _handleDioError(e);

    }

  }



  @override

  Future<Response<T>> delete<T>(

    String path, {

    dynamic data,

    Map<String, dynamic>? queryParameters,

    Options? options,

  }) async {

    try {

      return await _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);

    } on DioException catch (e) {

      throw _handleDioError(e);

    }

  }



  // ==========================================

  // Redesigned Dio Error Handling

  // ==========================================



  NetworkException _handleDioError(DioException error) {

    // 1. Connection and Timeout Errors (strictly map to ConnectionException)

    switch (error.type) {

      case DioExceptionType.connectionTimeout:

        return const ConnectionException(

          'انتهت مهلة محاولة الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',

        );

      case DioExceptionType.sendTimeout:

        return const ConnectionException(

          'انتهت مهلة إرسال البيانات إلى الخادم. يرجى التحقق من اتصال الإنترنت.',

        );

      case DioExceptionType.receiveTimeout:

        return const ConnectionException(

          'انتهت مهلة انتظار استجابة الخادم. يرجى المحاولة لاحقًا.',

        );

      case DioExceptionType.connectionError: case DioExceptionType.transformTimeout:

      case DioExceptionType.badCertificate:

        return ConnectionException(

          'فشل الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت (${error.message ?? "تعذر الوصول"}).',

        );

      case DioExceptionType.cancel:

        return const ConnectionException('تم إلغاء الطلب.');

      case DioExceptionType.unknown:

        if (error.error != null &&

            error.error.toString().toLowerCase().contains('socket')) {

          return const ConnectionException(

            'فشل الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',

          );

        }

        break;

      case DioExceptionType.badResponse:

        break;

    }



    // 2. HTTP Status Code Errors

    final status = error.response?.statusCode;

    final data = error.response?.data;

    final path = error.requestOptions.path;



    String? detailString;

    if (data is Map) {

      final detail = data['detail'];

      if (detail is String) {

        detailString = detail;

      }

    } else if (data is String) {

      detailString = data;

    }



    // 2.1 HTTP 400 Bad Request / Invalid Credentials

    if (status == 400) {

      final msg = detailString ?? error.message ?? 'طلب غير صالح.';

      if (msg.contains('اسم المستخدم أو كلمة المرور غير صحيحة') ||

          path.contains('/api/auth/login')) {

        return InvalidCredentialsException(msg);

      }

      return BadRequestException(msg, data);

    }



    // 2.2 HTTP 401 Unauthorized

    if (status == 401) {

      final msg = (detailString != null &&

              detailString.isNotEmpty &&

              detailString != 'Unauthorized')

          ? detailString

          : 'انتهت الجلسة أو يجب تسجيل الدخول';

      return UnauthorizedException(msg);

    }



    // 2.3 HTTP 403 Forbidden

    if (status == 403) {

      final msg = (detailString != null && detailString.isNotEmpty)

          ? detailString

          : 'ليس لديك صلاحية للقيام بهذا الإجراء';

      return ForbiddenException(msg);

    }



    // 2.4 HTTP 409 Conflict
    if (status == 409) {
      final msg = (detailString != null && detailString.isNotEmpty) ? detailString : 'تعارض في حالة الطلب. حاول مرة أخرى.';
      return ConflictException(msg);
    }

    // 2.4 HTTP 404 Not Found

    if (status == 404) {

      final msg = (detailString != null &&

              detailString.isNotEmpty &&

              detailString != 'Not Found')

          ? detailString

          : 'العنصر أو الصفحة المطلوبة غير موجودة';

      return NotFoundException(msg);

    }



    // 2.5 HTTP 422 Unprocessable Entity (FastAPI / Pydantic validation errors)

    if (status == 422) {

      return _parseValidationException(data);

    }



    // 2.6 HTTP 429 Too Many Requests (Rate Limiting)

    if (status == 429) {

      int? retryAfter;

      final retryHeader = error.response?.headers?.value('retry-after');

      if (retryHeader != null) {

        retryAfter = int.tryParse(retryHeader);

      }

      final msg = (detailString != null && detailString.isNotEmpty)

          ? detailString

          : 'تم تجاوز حد الطلبات المسموح به. يرجى الانتظار والمحاولة لاحقًا.';

      return RateLimitException(msg, retryAfter);

    }



    // 2.7 HTTP 500+ Server Errors

    if (status != null && status >= 500 && status < 600) {

      final msg = (detailString != null &&

              detailString.isNotEmpty &&

              detailString != 'Internal Server Error')

          ? detailString

          : 'حدث خطأ في الخادم. يرجى المحاولة لاحقًا.';

      return ServerException(msg, statusCode: status, data: data);

    }



    // Fallback ServerException

    final fallbackMsg = detailString ?? error.message ?? 'حدث خطأ غير متوقع';

    return ServerException(fallbackMsg, statusCode: status, data: data);

  }



  // ==========================================

  // Validation Localization Helpers

  // ==========================================



  static String _localizeFieldName(String field) {

    switch (field.toLowerCase()) {

      case 'username':

        return 'اسم المستخدم';

      case 'password':

        return 'كلمة المرور';

      case 'display_name':

        return 'الاسم المعروض';

      case 'current_password':

        return 'كلمة المرور الحالية';

      case 'new_password':

        return 'كلمة المرور الجديدة';

      case 'game':

        return 'نوع اللعبة';

      case 'room_id':

        return 'رقم الطاولة';

      case 'target_score':

        return 'النقاط المستهدفة';

      case 'message':

        return 'نص الرسالة';

      case 'amount':

        return 'المبلغ';

      case 'bio':

        return 'البايو';

      case 'gender':

        return 'الجنس';

      case 'rules':

        return 'قواعد اللعبة';

      default:

        return field;

    }

  }



  static String _localizeValidationError(Map<String, dynamic> err) {

    final loc = err['loc'];

    String fieldName = '';

    if (loc is List && loc.isNotEmpty) {

      fieldName = _localizeFieldName(loc.last.toString());

    }



    final msg = err['msg']?.toString() ?? '';

    final type = err['type']?.toString() ?? '';



    // If message already contains Arabic, preserve it

    if (RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) {

      return fieldName.isNotEmpty ? '$fieldName: $msg' : msg;

    }



    if (type == 'missing' || msg.toLowerCase().contains('field required')) {

      return fieldName.isNotEmpty ? 'حقل $fieldName مطلوب' : 'هذا الحقل مطلوب';

    }

    if (type == 'string_too_short' || msg.toLowerCase().contains('at least')) {

      return fieldName.isNotEmpty

          ? '$fieldName: القيمة أقصر من الحد الأدنى المسموح به'

          : 'القيمة أقصر من الحد الأدنى المسموح به';

    }

    if (type == 'string_too_long' || msg.toLowerCase().contains('at most')) {

      return fieldName.isNotEmpty

          ? '$fieldName: القيمة أطول من الحد الأقصى المسموح به'

          : 'القيمة أطول من الحد الأقصى المسموح به';

    }

    if (type.contains('int') || msg.toLowerCase().contains('integer')) {

      return fieldName.isNotEmpty

          ? '$fieldName: يجب إدخال رقم صحيح'

          : 'يجب إدخال رقم صحيح';

    }



    if (fieldName.isNotEmpty && msg.isNotEmpty) {

      return '$fieldName: $msg';

    }

    return msg.isNotEmpty ? msg : 'خطأ في التحقق من البيانات المدخلة';

  }



  static ValidationException _parseValidationException(dynamic data) {

    final List<String> formatted = [];

    dynamic rawDetail;



    if (data is Map<String, dynamic>) {

      rawDetail = data['detail'];

      if (rawDetail is List) {

        for (final item in rawDetail) {

          if (item is Map<String, dynamic>) {

            formatted.add(_localizeValidationError(item));

          } else if (item != null) {

            formatted.add(item.toString());

          }

        }

      } else if (rawDetail is String && rawDetail.isNotEmpty) {

        formatted.add(rawDetail);

      }

    } else if (data is String && data.isNotEmpty) {

      formatted.add(data);

    }



    final combined = formatted.isNotEmpty

        ? formatted.join('، ')

        : 'البيانات المدخلة غير صحيحة أو غير مكتملة';



    return ValidationException(

      combined,

      errors: formatted,

      rawErrors: rawDetail ?? data,

    );

  }

}

