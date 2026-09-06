/// Hermetic Mock WebSocket Backend for Let's Fly E2E Testing
/// Simulates /ws/events (lobby) and /ws/room/{room_id} (table/chat/gameplay)
library letsfly_mock_ws;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'test_fixtures.dart';

class MockWebSocketServer {
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  String get wsUrl => 'ws://127.0.0.1:$port';

  final List<WebSocket> _lobbyClients = [];
  final Map<String, List<WebSocket>> _roomClients = {};
  final Map<WebSocket, String> _socketUsers = {};
  final Map<WebSocket, List<DateTime>> _chatTimestamps = {};

  // Track actions for test assertions
  final List<Map<String, dynamic>> receivedActions = [];
  bool simulateSocketDrop = false;
  bool get isLobbyActive => _lobbyClients.isNotEmpty;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleUpgrade);
  }

  Future<void> stop() async {
    for (final client in List<WebSocket>.from(_lobbyClients)) {
      await client.close(WebSocketStatus.normalClosure);
    }
    _lobbyClients.clear();

    for (final clients in _roomClients.values) {
      for (final client in List<WebSocket>.from(clients)) {
        await client.close(WebSocketStatus.normalClosure);
      }
    }
    _roomClients.clear();

    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleUpgrade(HttpRequest request) async {
    final path = request.uri.path;
    if (path != '/ws/events' && !path.startsWith('/ws/room/')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final token = request.uri.queryParameters['token'] ??
        request.headers.value(HttpHeaders.authorizationHeader)?.replaceFirst('Bearer ', '');

    // Validate token
    if (token == null || token.isEmpty || !token.startsWith('mock_jwt_token_')) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    final username = token.split('_')[3]; // e.g. mock_jwt_token_alice_ver1 -> alice
    final socket = await WebSocketTransformer.upgrade(request);
    _socketUsers[socket] = username;
    _chatTimestamps[socket] = [];

    if (path == '/ws/events') {
      _lobbyClients.add(socket);
      // Send initial lobby presence
      socket.add(jsonEncode({
        'type': 'online_count',
        'count': 12,
      }));
      socket.listen(
        (data) => _handleLobbyMessage(socket, data),
        onDone: () => _lobbyClients.remove(socket),
        onError: (_) => _lobbyClients.remove(socket),
      );
    } else if (path.startsWith('/ws/room/')) {
      final roomId = path.substring('/ws/room/'.length);
      _roomClients.putIfAbsent(roomId, () => []).add(socket);

      // Send initial room snapshot
      socket.add(jsonEncode({
        'type': 'room_snapshot',
        'room': TestFixtures.createRoomSnapshot(roomId: roomId, hostUsername: username),
      }));

      socket.listen(
        (data) => _handleRoomMessage(roomId, socket, data),
        onDone: () => _roomClients[roomId]?.remove(socket),
        onError: (_) => _roomClients[roomId]?.remove(socket),
      );
    } else {
      await socket.close(WebSocketStatus.protocolError, 'Unknown endpoint');
    }
  }

  void _handleLobbyMessage(WebSocket socket, dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      receivedActions.add(data);
      final type = data['type'] as String?;

      if (type == 'ping') {
        socket.add(jsonEncode({'type': 'pong'}));
      }
    } catch (_) {}
  }

  void _handleRoomMessage(String roomId, WebSocket socket, dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      receivedActions.add(data);
      final action = data['action'] as String?;
      final user = _socketUsers[socket] ?? 'unknown';

      if (action == 'chat') {
        final text = data['text'] as String? ?? '';
        final now = DateTime.now();

        // Rate limit check: 10 messages per 5 seconds
        final timestamps = _chatTimestamps[socket]!;
        timestamps.removeWhere((t) => now.difference(t).inSeconds > 5);

        if (timestamps.length >= 10) {
          socket.add(jsonEncode({
            'type': 'error',
            'code': 'CHAT_RATE_LIMITED',
            'message': 'أنت ترسل الرسائل بسرعة كبيرة. يرجى الانتظار قليلاً.',
          }));
          return;
        }

        timestamps.add(now);
        // Broadcast chat to all room occupants
        broadcastToRoom(roomId, {
          'type': 'chat',
          'sender': user,
          'text': text,
          'timestamp': now.toIso8601String(),
        });
      } else if (action == 'game_action') {
        final subAction = data['sub_action'] as String?;
        if (subAction == 'play_card') {
          final cardId = data['card_id'];
          final chosenColor = data['chosen_color'];
          // Broadcast card play event
          broadcastToRoom(roomId, {
            'type': 'card_played',
            'player': user,
            'card_id': cardId,
            'chosen_color': chosenColor,
          });
        } else if (subAction == 'draw_card') {
          broadcastToRoom(roomId, {
            'type': 'card_drawn',
            'player': user,
            'count': 1,
          });
        } else if (subAction == 'call_uno') {
          broadcastToRoom(roomId, {
            'type': 'uno_called',
            'player': user,
          });
        } else if (subAction == 'catch_uno') {
          final target = data['target'];
          broadcastToRoom(roomId, {
            'type': 'uno_caught',
            'catcher': user,
            'target': target,
            'penalty_cards': 4,
          });
        }
      }
    } catch (_) {}
  }

  void broadcastToLobby(Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    for (final client in _lobbyClients) {
      client.add(payload);
    }
  }

  void broadcastToRoom(String roomId, Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    final clients = _roomClients[roomId];
    if (clients != null) {
      for (final client in clients) {
        client.add(payload);
      }
    }
  }

  void forceCloseRoom(String roomId) {
    final clients = _roomClients[roomId];
    if (clients != null) {
      for (final client in clients) {
        client.close(WebSocketStatus.normalClosure, 'Room closed');
      }
      clients.clear();
    }
  }
}
