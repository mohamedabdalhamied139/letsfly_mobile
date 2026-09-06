import 'dart:async';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/ws_client.dart';

abstract class LobbyWsService {
  Stream<Map<String, dynamic>> get lobbyEventStream;
  Stream<WsConnectionState> get connectionStateStream;
  Future<void> connect(String token, {String? wsHost});
  Future<void> disconnect();
}

class LobbyWsServiceImpl implements LobbyWsService {
  final WebSocketClient _client;
  StreamSubscription? _sub;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  LobbyWsServiceImpl({WebSocketClient? client})
      : _client = client ?? StandardWebSocketClient();

  @override
  Stream<Map<String, dynamic>> get lobbyEventStream => _controller.stream;

  @override
  Stream<WsConnectionState> get connectionStateStream => _client.stateStream;

  @override
  Future<void> connect(String token, {String? wsHost}) async {
    final host = wsHost ?? ApiEndpoints.defaultWsHost;
    final url = '$host/ws/events';

    // Subscribe before connecting so an immediate server event cannot be lost.
    await _sub?.cancel();
    _sub = _client.messages.listen((data) {
      if (data is Map<String, dynamic>) {
        _controller.add(data);
      }
    });

    try {
      await _client.connect(url, token: token);
    } catch (_) {
      await _sub?.cancel();
      _sub = null;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _client.disconnect();
  }
}
