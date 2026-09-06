import 'dart:async';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/ws_client.dart';
import '../models/chat_message_model.dart';
import '../models/room_model.dart';
import '../models/uno_game_state_model.dart';
import '../models/domino_state_model.dart';
import '../models/thief_hunt_state_model.dart';
import '../models/farkle_state_model.dart';

class RoomSnapshotData {
  final RoomModel room;
  final UnoGameStateModel? unoState;
  final FarkleStateModel? farkleState;
  final dynamic ninetyNineState;
  final dynamic tennisState;
  final DominoGameStateModel? dominoState;
  final ThiefHuntStateModel? thiefHuntState;
  final dynamic scopaState;
  final dynamic snakesAndLaddersState;
  final dynamic gameState;
  final String? gameType;
  final Map<String, dynamic> rawJson;

  const RoomSnapshotData({
    required this.room,
    this.unoState,
    this.farkleState,
    this.ninetyNineState,
    this.tennisState,
    this.dominoState,
    this.thiefHuntState,
    this.scopaState,
    this.snakesAndLaddersState,
    this.gameState,
    this.gameType,
    this.rawJson = const {},
  });
}

abstract class RoomWsService {
  Stream<RoomSnapshotData> get snapshotStream;
  Stream<ChatMessageModel> get chatStream;
  Stream<Map<String, dynamic>> get rawEventStream;
  Stream<List<int>> get voicePacketStream;
  Stream<WsConnectionState> get connectionStateStream;
  Future<void> sendJson(Map<String, dynamic> data);
  Future<void> sendBytes(List<int> data);
  WsConnectionState get state;

  Future<void> connect(String roomId, String token, {String? wsHost});
  Future<void> disconnect();
  Future<void> sendChat(String text);
  Future<void> sendGameAction(
    String action, {
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    int? tileIndex,
    String? side,
    dynamic data,
    Map<String, dynamic>? payload,
  });
  void dispatchGameState(RoomModel currentRoom, Map<String, dynamic> stateJson);
  RoomSnapshotData? get lastSnapshot;
  int get latencyMs;
  Future<void> reconnect();
}

class RoomWsServiceImpl implements RoomWsService {
  final WebSocketClient _client;
  StreamSubscription? _messageSub;

  final StreamController<RoomSnapshotData> _snapshotController =
      StreamController<RoomSnapshotData>.broadcast();
  final StreamController<ChatMessageModel> _chatController =
      StreamController<ChatMessageModel>.broadcast();
  final StreamController<Map<String, dynamic>> _rawEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<int>> _voicePacketController =
      StreamController<List<int>>.broadcast();

  RoomSnapshotData? _lastSnapshot;

  RoomWsServiceImpl({WebSocketClient? client})
      : _client = client ?? StandardWebSocketClient();

  @override
  RoomSnapshotData? get lastSnapshot => _lastSnapshot;

  @override
  int get latencyMs => _client.latencyMs;

  @override
  Future<void> reconnect() => _client.reconnect();

  @override
  Stream<RoomSnapshotData> get snapshotStream => _snapshotController.stream;

  @override
  Stream<ChatMessageModel> get chatStream => _chatController.stream;

  @override
  Stream<Map<String, dynamic>> get rawEventStream => _rawEventController.stream;

  @override
  Stream<List<int>> get voicePacketStream => _voicePacketController.stream;

  @override
  Stream<WsConnectionState> get connectionStateStream => _client.stateStream;

  @override
  WsConnectionState get state => _client.connectionState;

  @override
  Future<void> connect(String roomId, String token, {String? wsHost}) async {
    final host = wsHost ?? ApiEndpoints.defaultWsHost;
    final url = '$host/ws/room/$roomId';

    // Subscribe BEFORE opening the socket. The server sends room_snapshot
    // immediately after a successful room connection.
    await _messageSub?.cancel();
    _messageSub = _client.messages.listen(_handleIncomingMessage);

    try {
      await _client.connect(url, token: token);
    } catch (_) {
      await _messageSub?.cancel();
      _messageSub = null;
      rethrow;
    }
  }

  void _handleIncomingMessage(dynamic data) {
    if (data is List<int>) { _voicePacketController.add(data); return; }
    if (data is! Map<String, dynamic>) return;
    _rawEventController.add(data);

    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'room_snapshot':
        final roomMap = data['room'] as Map<String, dynamic>? ?? {};
        final unoMap = data['uno_state'] as Map<String, dynamic>?;
        final ninetyNineMap = data['ninety_nine_state'] as Map<String, dynamic>?;
        final tennisMap = data['tennis_state'] as Map<String, dynamic>?;
        final dominoMap =
            (data['domino_state'] ?? data['american_domino_state']) as Map<String, dynamic>?;
        final thiefMap = data['thief_state'] as Map<String, dynamic>?;
        final farkleMap = data['farkle_state'] as Map<String, dynamic>?;

        final snapshot = RoomSnapshotData(
          room: RoomModel.fromJson(roomMap),
          unoState: unoMap != null ? UnoGameStateModel.fromJson(unoMap) : null,
          ninetyNineState: ninetyNineMap,
          tennisState: tennisMap,
          dominoState: dominoMap != null ? DominoGameStateModel.fromJson(dominoMap) : null,
          thiefHuntState: thiefMap != null ? ThiefHuntStateModel.fromJson(thiefMap) : null,
          farkleState: farkleMap != null ? FarkleStateModel.fromJson(farkleMap) : null,
          scopaState: data['scopa_state'],
          snakesAndLaddersState: data['snakes_and_ladders_state'],
          gameState: data['game_state'],
          gameType: data['game_type']?.toString(),
          rawJson: data,
        );
        _lastSnapshot = snapshot;
        _snapshotController.add(snapshot);
        break;

      case 'chat_message':
        final chat = ChatMessageModel.fromJson(data);
        _chatController.add(chat);
        break;

      default:
        // Other events (player_joined, bot_added, etc.) are available on rawEventStream.
        break;
    }
  }

  @override
  Future<void> sendJson(Map<String, dynamic> data) => _client.sendJson(data);

  @override
  Future<void> sendBytes(List<int> data) => _client.sendBytes(data);

  @override
  Future<void> sendChat(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _client.sendJson({'text': clean});
  }

  @override
  Future<void> sendGameAction(
    String action, {
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    int? tileIndex,
    String? side,
    dynamic data,
    Map<String, dynamic>? payload,
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final payloadMap = <String, dynamic>{
      'action': action,
      if (cardId != null) 'card_id': cardId,
      if (chosenColor != null) 'chosen_color': chosenColor,
      if (targetPlayerId != null) 'target_player_id': targetPlayerId,
      if (tileIndex != null) 'tile_index': tileIndex,
      if (side != null) 'side': side,
    };
    if (data != null) {
      payloadMap['data'] = data;
    }
    if (payload != null) {
      payloadMap['data'] = {...?payload, if (data is Map) ...data};
    }

    // Keep the established application envelope. The important part is that
    // the constructed payloadMap is actually sent instead of the nullable
    // optional parameter (which previously made every normal action null).
    await _client.sendJson({
      'type': 'game_action',
      'request_id': requestId,
      'payload': payloadMap,
    });
  }

  @override
  void dispatchGameState(RoomModel currentRoom, Map<String, dynamic> stateJson) {
    final gameType = (stateJson['game_type']?.toString() ?? currentRoom.game).toUpperCase();
    UnoGameStateModel? unoState;
    DominoGameStateModel? dominoState;
    ThiefHuntStateModel? thiefHuntState;
    FarkleStateModel? farkleState;
    dynamic ninetyNineState;
    dynamic tennisState;
    dynamic scopaState;
    dynamic snakesAndLaddersState;

    if (gameType == 'UNO') {
      try { unoState = UnoGameStateModel.fromJson(stateJson); } catch (_) {}
    } else if (gameType == 'DOMINO' || gameType == 'AMERICAN_DOMINO') {
      try { dominoState = DominoGameStateModel.fromJson(stateJson); } catch (_) {}
    } else if (gameType == 'THIEF_HUNT') {
      try { thiefHuntState = ThiefHuntStateModel.fromJson(stateJson); } catch (_) {}
    } else if (gameType == 'FARKLE') {
      try { farkleState = FarkleStateModel.fromJson(stateJson); } catch (_) {}
    } else if (gameType == 'NINETY_NINE' || gameType == 'NINETYNINE') {
      ninetyNineState = stateJson;
    } else if (gameType == 'TENNIS') {
      tennisState = stateJson;
    } else if (gameType == 'SCOPA') {
      scopaState = stateJson;
    } else if (gameType == 'SNAKES_LADDERS') {
      snakesAndLaddersState = stateJson;
    }

    final snapshot = RoomSnapshotData(
      room: currentRoom,
      unoState: unoState,
      dominoState: dominoState,
      thiefHuntState: thiefHuntState,
      farkleState: farkleState,
      ninetyNineState: ninetyNineState,
      tennisState: tennisState,
      scopaState: scopaState,
      snakesAndLaddersState: snakesAndLaddersState,
      gameState: stateJson,
      gameType: gameType,
      rawJson: stateJson,
    );
    _lastSnapshot = snapshot;
    _snapshotController.add(snapshot);
  }

  @override
  Future<void> disconnect() async {
    await _messageSub?.cancel();
    _messageSub = null;
    await _client.disconnect();
  }
}
