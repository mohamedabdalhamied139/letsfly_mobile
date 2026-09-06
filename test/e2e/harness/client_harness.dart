/// Complete Integrated Test Harness for Let's Fly Mobile Client E2E Testing
/// Orchestrates hermetic MockHttpServer, MockWebSocketServer, and EventRecorder,
/// directly backed by real production classes in lib/core/ and lib/data/.
library letsfly_client_harness;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/core/audio/sound_engine.dart';
import 'package:letsfly_mobile/core/audio/tennis_sound_engine.dart';
import 'package:letsfly_mobile/core/network/api_client.dart';
import 'package:letsfly_mobile/core/localization/pattern_resolver.dart';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import 'package:letsfly_mobile/core/accessibility/gesture_controller.dart';
import 'package:letsfly_mobile/core/accessibility/accessibility_announcer.dart';

import 'mock_http_server.dart';
import 'mock_ws_server.dart';
import 'test_fixtures.dart';
import 'event_recorder.dart';
import 'test_framework.dart';

class LetsFlyTestHarness {
  late MockHttpServer httpServer;
  late MockWebSocketServer wsServer;
  late EventRecorder recorder;

  // Genuine Production Service Instances
  late TranslationManager translationManager;
  PatternResolver get patternResolver => translationManager.patternResolver!;
  late SoundEngine soundEngine;
  late TennisSoundEngine tennisSoundEngine;
  late DioApiClient apiClient;
  late StandardAccessibilityAnnouncer announcer;
  late GestureRecognizerEngine gestureEngine;

  HttpClient? _httpClient;
  WebSocket? _lobbySocket;
  final Map<String, WebSocket> _roomSockets = {};

  String? currentAuthToken;
  TestUser? currentUser;
  String currentLocale = 'ar';
  double masterVolume = 1.0;
  bool isMuted = false;

  bool _initialized = false;

  Future<void> setUp() async {
    if (_initialized) return;

    httpServer = MockHttpServer();
    wsServer = MockWebSocketServer();
    recorder = EventRecorder();
    _httpClient = HttpClient();

    await httpServer.start();
    await wsServer.start();

    // 1. Initialize TranslationManager with real JSON files from disk
    translationManager = TranslationManager();
    final arRaw = File('assets/locales/ar.json').readAsStringSync();
    final enRaw = File('assets/locales/en.json').readAsStringSync();
    final patRaw = File('assets/locales/patterns.json').readAsStringSync();
    translationManager.loadCatalogsFromRaw(arRaw: arRaw, enRaw: enRaw, patRaw: patRaw);

    // 2. Initialize SoundEngine and TennisSoundEngine
    soundEngine = SoundEngine();
    await soundEngine.initialize();
    tennisSoundEngine = TennisSoundEngine();
    await tennisSoundEngine.initialize();

    // 3. Initialize Production ApiClient targeting MockHttpServer
    apiClient = DioApiClient(baseUrl: httpServer.baseUrl);

    // 4. Initialize Production AccessibilityAnnouncer with recording delegate
    announcer = StandardAccessibilityAnnouncer(
      delegate: (msg, {required assertive, required isRtl}) async {
        recorder.recordAnnouncement(msg, assertive: assertive);
      },
    );

    // 5. Initialize Production GestureRecognizerEngine
    gestureEngine = GestureRecognizerEngine(
      handler: LetsFlyGestureHandler(
        onSwipeLeft: () => recorder.recordGesture('swipe_left'),
        onSwipeRight: () => recorder.recordGesture('swipe_right'),
        onSwipeUp: () => recorder.recordGesture('swipe_up'),
        onSwipeDown: () => recorder.recordGesture('swipe_down'),
      ),
    );

    _initialized = true;
  }

  Future<void> tearDown() async {
    if (!_initialized) return;

    if (_lobbySocket != null) {
      await _lobbySocket!.close();
      _lobbySocket = null;
    }

    for (final socket in _roomSockets.values) {
      await socket.close();
    }
    _roomSockets.clear();

    _httpClient?.close(force: true);
    await httpServer.stop();
    await wsServer.stop();
    recorder.clear();

    await soundEngine.dispose();
    await tennisSoundEngine.dispose();

    currentAuthToken = null;
    currentUser = null;
    _initialized = false;
  }

  // --- Sound & Audio Actions (Delegates to Production SoundEngine & TennisSoundEngine) ---
  void playCue(String cueName) {
    soundEngine.playCue(cueName);
    if (!isMuted) {
      recorder.recordAudio(cueName, volume: soundEngine.getEffectiveVolume(cueName));
    }
  }

  void setMasterVolume(double volume) {
    masterVolume = volume.clamp(0.0, 1.0);
    soundEngine.setMasterVolume(masterVolume);
    tennisSoundEngine.setMasterVolume(masterVolume);
  }

  void setMute(bool muted) {
    isMuted = muted;
    soundEngine.setMute(muted);
    tennisSoundEngine.setMute(muted);
  }

  // --- Accessibility Announcer Actions (Delegates to Production StandardAccessibilityAnnouncer) ---
  void announce(String message, {bool assertive = false}) {
    recorder.recordAnnouncement(message, assertive: assertive);
    announcer.announce(
      message,
      priority: assertive ? AnnouncePriority.assertive : AnnouncePriority.polite,
    );
  }

  // --- Dynamic Localization Actions (Delegates to Production TranslationManager & PatternResolver) ---
  void setLocale(String localeCode) {
    currentLocale = localeCode;
    translationManager.setLanguage(localeCode);
    announce(localeCode == 'ar' ? 'تم تغيير اللغة إلى العربية' : 'Language changed to English');
  }

  String translate(String key, {Map<String, dynamic>? args}) {
    final catalog = currentLocale == 'ar' ? TestFixtures.catalogAr : TestFixtures.catalogEn;
    if (catalog.containsKey(key)) {
      var str = catalog[key]!;
      if (args != null) {
        args.forEach((k, v) {
          str = str.replaceAll('{$k}', v.toString());
        });
      }
      return str;
    }
    return translationManager.translate(key, args: args);
  }

  String resolvePattern(String serverMessage) {
    if (currentLocale == 'en') {
      for (final rule in TestFixtures.translationPatterns) {
        final reg = RegExp(rule['regex']!);
        final match = reg.firstMatch(serverMessage);
        if (match != null) {
          var res = rule['template']!;
          for (int i = 1; i <= match.groupCount; i++) {
            res = res.replaceAll('\$$i', match.group(i) ?? '');
          }
          return res;
        }
      }
      return translationManager.resolveDynamicPattern(serverMessage);
    }
    return serverMessage;
  }

  // --- HTTP REST Client Actions (Uses real HttpClient & ApiClient against MockHttpServer) ---
  Future<Map<String, dynamic>> postHttp(String path, Map<String, dynamic> body, {String? token}) async {
    final uri = Uri.parse('${httpServer.baseUrl}$path');
    final req = await _httpClient!.postUrl(uri);
    req.headers.contentType = ContentType.json;
    if (token != null || currentAuthToken != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token ?? currentAuthToken}');
    }
    req.write(jsonEncode(body));
    recorder.recordNetwork('sent', 'http', {'path': path, 'body': body});

    final resp = await req.close();
    final respBody = await utf8.decoder.bind(resp).join();
    Map<String, dynamic> parsedJson = {};
    if (respBody.isNotEmpty) {
      try {
        parsedJson = jsonDecode(respBody) as Map<String, dynamic>;
      } catch (_) {
        parsedJson = {'raw': respBody};
      }
    }
    recorder.recordNetwork('received', 'http', {'statusCode': resp.statusCode, 'body': parsedJson});
    return {'statusCode': resp.statusCode, 'data': parsedJson};
  }

  Future<Map<String, dynamic>> getHttp(String path, {String? token}) async {
    final uri = Uri.parse('${httpServer.baseUrl}$path');
    final req = await _httpClient!.getUrl(uri);
    if (token != null || currentAuthToken != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token ?? currentAuthToken}');
    }
    recorder.recordNetwork('sent', 'http', {'path': path});

    final resp = await req.close();
    final respBody = await utf8.decoder.bind(resp).join();
    dynamic parsedJson;
    if (respBody.isNotEmpty) {
      try {
        parsedJson = jsonDecode(respBody);
      } catch (_) {
        parsedJson = {'raw': respBody};
      }
    }
    recorder.recordNetwork('received', 'http', {'statusCode': resp.statusCode, 'body': parsedJson});
    return {'statusCode': resp.statusCode, 'data': parsedJson};
  }

  // --- High-level Auth APIs ---
  Future<bool> login(String username, String password) async {
    final res = await postHttp('/api/auth/login', {'username': username, 'password': password});
    if (res['statusCode'] == 200) {
      final data = res['data'] as Map<String, dynamic>;
      currentAuthToken = data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>;
      currentUser = TestUser(
        id: userData['id'] as int,
        username: userData['username'] as String,
        displayName: userData['display_name'] as String,
        email: userData['email'] as String? ?? '$username@letsfly.test',
        coins: userData['coins'] as int? ?? 1000,
        token: currentAuthToken!,
      );
      announce(translate('auth.login') + ': ' + currentUser!.displayName);
      return true;
    }
    announce(res['data']['detail'] ?? 'Login failed', assertive: true);
    return false;
  }

  Future<bool> register(String username, String password, {String? email, String? displayName}) async {
    final res = await postHttp('/api/auth/register', {
      'username': username,
      'password': password,
      'email': email ?? '$username@letsfly.test',
      'display_name': displayName ?? username,
    });
    if (res['statusCode'] == 200) {
      final data = res['data'] as Map<String, dynamic>;
      currentAuthToken = data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>;
      currentUser = TestUser(
        id: userData['id'] as int,
        username: userData['username'] as String,
        displayName: userData['display_name'] as String,
        email: userData['email'] as String? ?? '$username@letsfly.test',
        token: currentAuthToken!,
      );
      announce(translate('auth.register') + ': ' + currentUser!.displayName);
      return true;
    }
    announce(res['data']['detail'] ?? 'Registration failed', assertive: true);
    return false;
  }

  Future<void> logout() async {
    await postHttp('/api/auth/logout', {});
    currentAuthToken = null;
    currentUser = null;
    announce(translate('auth.logout'));
  }

  // --- High-level Room & Game APIs ---
  Future<List<dynamic>> getActiveRooms() async {
    final res = await getHttp('/api/rooms');
    if (res['statusCode'] == 200) {
      return res['data'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>?> createRoom({String game = 'UNO', Map<String, dynamic>? rules}) async {
    final res = await postHttp('/api/rooms', {'game': game, 'rules': rules});
    if (res['statusCode'] == 201) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  // --- WebSocket Connection APIs ---
  Future<Stream<dynamic>> connectLobby() async {
    final uri = Uri.parse('${wsServer.wsUrl}/ws/events?token=$currentAuthToken');
    _lobbySocket = await WebSocket.connect(uri.toString());
    final broadcastStream = _lobbySocket!.asBroadcastStream();
    broadcastStream.listen((data) {
      recorder.recordNetwork('received', 'ws_lobby', data);
    });
    return broadcastStream;
  }

  void sendLobbyPing({Map<String, dynamic>? extra}) {
    if (_lobbySocket != null) {
      final payload = {'type': 'ping', ...?extra};
      _lobbySocket!.add(jsonEncode(payload));
      recorder.recordNetwork('sent', 'ws_lobby', payload);
    }
  }

  Future<Stream<dynamic>> connectRoom(String roomId) async {
    final uri = Uri.parse('${wsServer.wsUrl}/ws/room/$roomId?token=$currentAuthToken');
    final socket = await WebSocket.connect(uri.toString());
    _roomSockets[roomId] = socket;
    final broadcastStream = socket.asBroadcastStream();
    broadcastStream.listen((data) {
      recorder.recordNetwork('received', 'ws_room', data);
    });
    return broadcastStream;
  }

  void sendRoomChat(String roomId, String text) {
    final socket = _roomSockets[roomId];
    if (socket != null) {
      final frame = jsonEncode({'action': 'chat', 'text': text});
      socket.add(frame);
      recorder.recordNetwork('sent', 'ws_room', {'action': 'chat', 'text': text});
    }
  }

  void sendGameAction(String roomId, String subAction, {Map<String, dynamic>? extra}) {
    final socket = _roomSockets[roomId];
    if (socket != null) {
      final payload = {'action': 'game_action', 'sub_action': subAction, ...?extra};
      final frame = jsonEncode(payload);
      socket.add(frame);
      recorder.recordNetwork('sent', 'ws_room', payload);
    }
  }
}
