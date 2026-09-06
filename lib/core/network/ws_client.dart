import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'network_exceptions.dart';

/// Connection state of a WebSocket client.
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Abstract contract for WebSocket connections.
abstract class WebSocketClient {
  Stream<dynamic> get messages;
  Stream<WsConnectionState> get stateStream;
  WsConnectionState get connectionState;
  int get latencyMs;
  Stream<int> get latencyStream;
  Future<void> connect(String url, {String? token});
  Future<void> reconnect();
  Future<void> disconnect();
  Future<void> sendJson(Map<String, dynamic> data);
  Future<void> sendRaw(String text);
  Future<void> sendBytes(List<int> data);
}

/// WebSocket client implementation using web_socket_channel.
///
/// It preserves the existing public contract while making connection lifecycle
/// safe: old sockets are cleaned up before replacement, messages are listened
/// to immediately, and an established connection is automatically restored
/// after an unexpected disconnect.
class StandardWebSocketClient implements WebSocketClient {
  WebSocketChannel? _channel;
  final StreamController<dynamic> _messageController =
      StreamController<dynamic>.broadcast();
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  final StreamController<int> _latencyController =
      StreamController<int>.broadcast();

  WsConnectionState _state = WsConnectionState.disconnected;
  StreamSubscription? _channelSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _lastUrl;
  String? _lastToken;
  bool _manualDisconnect = false;
  bool _hasEstablishedConnection = false;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  int _latencyMs = 0;
  final Map<String, int> _pingTimestamps = {};

  @override
  Stream<dynamic> get messages => _messageController.stream;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  @override
  WsConnectionState get connectionState => _state;

  @override
  int get latencyMs => _latencyMs;

  @override
  Stream<int> get latencyStream => _latencyController.stream;

  void _setState(WsConnectionState newState) {
    if (_disposed || _state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> connect(String url, {String? token}) async {
    _lastUrl = url;
    _lastToken = token;
    _manualDisconnect = false;
    _hasEstablishedConnection = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionGeneration++;
    final generation = _connectionGeneration;

    // A service can legitimately reconnect/re-enter a table. Never leave an
    // older socket alive while replacing it with a new one.
    await _closeCurrentSocket();
    if (_disposed || generation != _connectionGeneration) return;

    await _open(url, token: token, generation: generation, isReconnect: false);
  }

  Future<void> _open(
    String url, {
    required String? token,
    required int generation,
    required bool isReconnect,
  }) async {
    if (_disposed || generation != _connectionGeneration || _manualDisconnect) return;

    _setState(isReconnect ? WsConnectionState.reconnecting : WsConnectionState.connecting);

    try {
      final uri = Uri.parse(url);
      final finalUri = token != null && token.isNotEmpty
          ? uri.replace(queryParameters: {...uri.queryParameters, 'token': token})
          : uri;

      final channel = WebSocketChannel.connect(finalUri);
      _channel = channel;

      // Attach the stream listener immediately. Some servers send the initial
      // snapshot as soon as the WebSocket handshake completes.
      _channelSub = channel.stream.listen(
        (data) {
          try {
            if (data is String) {
              final decoded = jsonDecode(data);
              if (decoded is Map<String, dynamic> && decoded['type'] == 'pong') {
                final pingId = decoded['ping_id']?.toString();
                final sent = pingId != null ? _pingTimestamps.remove(pingId) : null;
                if (sent != null) {
                  _latencyMs = DateTime.now().millisecondsSinceEpoch - sent;
                  _latencyController.add(_latencyMs);
                }
              }
              _messageController.add(decoded);
            } else {
              _messageController.add(data);
            }
          } catch (_) {
            _messageController.add(data);
          }
        },
        onError: (Object err, StackTrace stack) {
          debugPrint('[WebSocketClient] Error on stream: $err');
          if (generation == _connectionGeneration) {
            _handleUnexpectedDisconnect(generation);
          }
        },
        onDone: () {
          debugPrint('[WebSocketClient] Socket stream completed/closed');
          if (generation == _connectionGeneration) {
            _handleUnexpectedDisconnect(generation);
          }
        },
        cancelOnError: false,
      );

      await channel.ready;
      if (_disposed || generation != _connectionGeneration || _channel != channel) {
        await _closeChannel(channel);
        return;
      }

      _hasEstablishedConnection = true;
      _reconnectAttempt = 0;
      _setState(WsConnectionState.connected);
      _startHeartbeat(generation);
    } catch (e) {
      if (generation != _connectionGeneration || _manualDisconnect || _disposed) return;

      await _closeCurrentSocket();
      _setState(WsConnectionState.disconnected);

      if (isReconnect) {
        _scheduleReconnect(generation);
      } else {
        throw WebSocketException('Failed to connect to WebSocket: $e');
      }
    }
  }

  void _handleUnexpectedDisconnect(int generation) {
    if (_disposed || _manualDisconnect || generation != _connectionGeneration) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel = null;
    _channelSub = null;

    if (_hasEstablishedConnection) {
      _scheduleReconnect(generation);
    } else {
      _setState(WsConnectionState.disconnected);
    }
  }

  void _scheduleReconnect(int generation) {
    if (_disposed || _manualDisconnect || generation != _connectionGeneration) return;
    if (_lastUrl == null) return;
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempt++;
    final seconds = (1 << (_reconnectAttempt - 1)).clamp(1, 30);
    _setState(WsConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      if (_disposed || _manualDisconnect || generation != _connectionGeneration) return;
      final url = _lastUrl;
      if (url == null) return;
      try {
        await _open(
          url,
          token: _lastToken,
          generation: generation,
          isReconnect: true,
        );
      } catch (e) {
        debugPrint('[WebSocketClient] Reconnect failed: $e');
        _scheduleReconnect(generation);
      }
    });
  }

  void _startHeartbeat(int generation) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (generation != _connectionGeneration ||
          _state != WsConnectionState.connected) {
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final pingId = now.toString();
      _pingTimestamps[pingId] = now;
      if (_pingTimestamps.length > 20) {
        _pingTimestamps.remove(_pingTimestamps.keys.first);
      }
      sendJson({
        'type': 'ping',
        'ping_id': pingId,
      }).catchError((Object error) {
        debugPrint('[WebSocketClient] Heartbeat failed: $error');
      });
    });
  }

  @override
  Future<void> reconnect() async {
    if (_disposed || _lastUrl == null) return;
    final url = _lastUrl!;
    final token = _lastToken;
    await connect(url, token: token);
  }

  @override
  Future<void> sendJson(Map<String, dynamic> data) async {
    if (_state != WsConnectionState.connected || _channel == null) {
      throw const WebSocketException('Cannot send message: WebSocket is not connected');
    }
    final encoded = jsonEncode(data);
    _channel!.sink.add(encoded);
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    if (_state != WsConnectionState.connected || _channel == null) {
      throw const WebSocketException('Cannot send bytes: WebSocket is not connected');
    }
    if (data.length > 4096) {
      throw const WebSocketException('Binary message is too large');
    }
    _channel!.sink.add(data);
  }

  @override
  Future<void> sendRaw(String text) async {
    if (_state != WsConnectionState.connected || _channel == null) {
      throw const WebSocketException('Cannot send message: WebSocket is not connected');
    }
    _channel!.sink.add(text);
  }

  Future<void> _closeChannel(WebSocketChannel channel) async {
    try {
      await channel.sink.close();
    } catch (_) {}
  }

  Future<void> _closeCurrentSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final sub = _channelSub;
    _channelSub = null;
    await sub?.cancel();

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _closeChannel(channel);
    }
  }

  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _hasEstablishedConnection = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionGeneration++;
    await _closeCurrentSocket();
    if (!_disposed) {
      _setState(WsConnectionState.disconnected);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectionGeneration++;
    _closeCurrentSocket();
    _messageController.close();
    _stateController.close();
    _latencyController.close();
  }
}
