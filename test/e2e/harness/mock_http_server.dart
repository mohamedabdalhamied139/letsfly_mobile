/// Hermetic Mock HTTP Backend for Let's Fly E2E Testing
/// Simulates all FastAPI REST endpoints, auth flows, room CRUD, and security controls.
library letsfly_mock_http;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'test_fixtures.dart';

class MockHttpServer {
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  String get baseUrl => 'http://127.0.0.1:$port';

  final Map<String, TestUser> _registeredUsers = {};
  final Map<String, String> _activeTokens = {}; // token -> username
  final Map<String, Map<String, dynamic>> _rooms = {};
  int _tokenVersion = 1;

  // Rate limiting / failure injection flags
  bool simulate500Error = false;
  bool simulateRateLimit429 = false;
  int? customStatusCode;
  String? customErrorDetail;

  MockHttpServer() {
    // Seed standard fixtures
    _registeredUsers[TestFixtures.userAlice.username] = TestFixtures.userAlice;
    _registeredUsers[TestFixtures.userBob.username] = TestFixtures.userBob;
    _registeredUsers[TestFixtures.userCharlie.username] = TestFixtures.userCharlie;

    _activeTokens[TestFixtures.userAlice.token] = TestFixtures.userAlice.username;
    _activeTokens[TestFixtures.userBob.token] = TestFixtures.userBob.username;

    // Seed default room
    final standardRoom = TestFixtures.createRoomSnapshot(
      roomId: 'room_101',
      hostUsername: 'alice',
    );
    _rooms['room_101'] = standardRoom;
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // Standard headers
    request.response.headers.add('X-Content-Type-Options', 'nosniff');
    request.response.headers.add('X-LetsFly-Process-Time-Ms', '12');

    // Read body
    final bodyString = await utf8.decoder.bind(request).join();

    // Body size guard (64KB)
    final contentLength = request.headers.contentLength;
    if (contentLength > 64 * 1024 || bodyString.length > 64 * 1024) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': 'حجم الطلب كبير جدًا.'}));
      await request.response.close();
      return;
    }

    if (simulate500Error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': 'Internal Server Error'}));
      await request.response.close();
      return;
    }

    if (simulateRateLimit429) {
      request.response.statusCode = HttpStatus.tooManyRequests;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': 'Too Many Requests'}));
      await request.response.close();
      return;
    }

    if (customStatusCode != null) {
      request.response.statusCode = customStatusCode!;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': customErrorDetail ?? 'Custom Error'}));
      await request.response.close();
      return;
    }

    Map<String, dynamic> bodyJson = {};
    if (bodyString.isNotEmpty) {
      try {
        bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Extract Bearer token
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    String? bearerToken;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      bearerToken = authHeader.substring(7);
    }

    try {
      if (path == '/api/auth/register' && method == 'POST') {
        final username = bodyJson['username'] as String?;
        final password = bodyJson['password'] as String?;
        final email = bodyJson['email'] as String? ?? '';

        if (username == null || password == null || username.isEmpty || password.isEmpty) {
          request.response.statusCode = HttpStatus.unprocessableEntity;
          request.response.write(jsonEncode({'detail': 'اسم المستخدم وكلمة المرور مطلوبان.'}));
        } else if (password.length > 72) {
          // Bcrypt truncation guard
          request.response.statusCode = HttpStatus.unprocessableEntity;
          request.response.write(jsonEncode({'detail': 'كلمة المرور طويلة جدًا (الحد الأقصى 72 بايت).'}));
        } else if (_registeredUsers.containsKey(username)) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(jsonEncode({'detail': 'اسم المستخدم مستخدم بالفعل.'}));
        } else {
          final token = 'mock_jwt_token_${username}_ver1';
          final newUser = TestUser(
            id: _registeredUsers.length + 1,
            username: username,
            displayName: bodyJson['display_name'] as String? ?? username,
            email: email,
            coins: 1000,
            tokenVersion: 1,
            token: token,
          );
          _registeredUsers[username] = newUser;
          _activeTokens[token] = username;

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'user': newUser.toJson(),
          }));
        }
      } else if (path == '/api/auth/login' && method == 'POST') {
        final username = bodyJson['username'] as String?;
        final password = bodyJson['password'] as String?;

        if (username != null && _registeredUsers.containsKey(username) && password != null && password.isNotEmpty) {
          final user = _registeredUsers[username]!;
          final token = 'mock_jwt_token_${username}_ver$_tokenVersion';
          _activeTokens[token] = username;

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'user': user.toJson(),
          }));
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'detail': 'بيانات الاعتماد غير صالحة.'}));
        }
      } else if (path == '/api/auth/me' && method == 'GET') {
        if (bearerToken != null && _activeTokens.containsKey(bearerToken)) {
          final username = _activeTokens[bearerToken]!;
          final user = _registeredUsers[username]!;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(user.toJson()));
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'detail': 'غير مصرح'}));
        }
      } else if (path == '/api/auth/logout' && method == 'POST') {
        if (bearerToken != null && _activeTokens.containsKey(bearerToken)) {
          _activeTokens.remove(bearerToken);
          _tokenVersion++;
        }
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'detail': 'تم تسجيل الخروج بنجاح.'}));
      } else if (path == '/api/rooms' && method == 'GET') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_rooms.values.toList()));
      } else if (path == '/api/rooms' && method == 'POST') {
        final roomId = 'room_${_rooms.length + 101}';
        final host = bearerToken != null ? (_activeTokens[bearerToken] ?? 'alice') : 'alice';
        final newRoom = TestFixtures.createRoomSnapshot(
          roomId: roomId,
          hostUsername: host,
          game: bodyJson['game'] as String? ?? 'UNO',
          rules: bodyJson['rules'] as Map<String, dynamic>?,
        );
        _rooms[roomId] = newRoom;
        request.response.statusCode = HttpStatus.created;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(newRoom));
      } else if (path.startsWith('/api/rooms/') && path.endsWith('/join') && method == 'POST') {
        final segments = path.split('/');
        final roomId = segments[3];
        if (_rooms.containsKey(roomId)) {
          final user = bearerToken != null ? _activeTokens[bearerToken] : 'guest';
          final room = _rooms[roomId]!;
          final players = List<Map<String, dynamic>>.from(room['players'] as List);
          if (!players.any((p) => p['username'] == user)) {
            players.add({'id': players.length + 1, 'username': user, 'is_host': false, 'is_bot': false, 'cards_count': 7});
            room['players'] = players;
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(room));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'detail': 'الطاولة غير موجودة.'}));
        }
      } else if (path.startsWith('/api/rooms/') && path.endsWith('/leave') && method == 'POST') {
        final segments = path.split('/');
        final roomId = segments[3];
        if (_rooms.containsKey(roomId)) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'detail': 'تمت المغادرة.'}));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'detail': 'الطاولة غير موجودة.'}));
        }
      } else if (path.startsWith('/api/rooms/') && path.endsWith('/bots') && method == 'POST') {
        final segments = path.split('/');
        final roomId = segments[3];
        if (_rooms.containsKey(roomId)) {
          final room = _rooms[roomId]!;
          final players = List<Map<String, dynamic>>.from(room['players'] as List);
          final botId = players.length + 1;
          final bot = {'id': botId, 'username': 'bot_$botId', 'is_host': false, 'is_bot': true, 'cards_count': 7};
          players.add(bot);
          room['players'] = players;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(bot));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'detail': 'الطاولة غير موجودة.'}));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'detail': 'المسار غير موجود.'}));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': e.toString()}));
    } finally {
      await request.response.close();
    }
  }
}
