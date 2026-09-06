import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/room_model.dart';

class RoomRemoteDataSource {
  final ApiClient _client;

  RoomRemoteDataSource({required ApiClient client}) : _client = client;

  Future<List<RoomModel>> listRooms() async {
    final res = await _client.get(ApiEndpoints.rooms);
    final list = res.data as List<dynamic>? ?? [];
    return list
        .map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<RoomModel> createRoom({String game = 'UNO'}) async {
    final res = await _client.post(
      ApiEndpoints.createRoom,
      data: {'game': game},
    );
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomModel> getRoom(String roomId) async {
    final res = await _client.get(ApiEndpoints.room(roomId));
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomModel> joinRoom(String roomId) async {
    final res = await _client.post(ApiEndpoints.joinRoom(roomId));
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      await _client.post(ApiEndpoints.leaveRoom(roomId));
    } catch (_) {}
  }

  Future<RoomModel> addBot(String roomId) async {
    final res = await _client.post(ApiEndpoints.addBot(roomId));
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> removeBot(String roomId) async {
    await _client.post('${ApiEndpoints.removeBot(roomId)}/remove');
  }

  Future<RoomModel> startGame(
    String roomId, {
    int? targetScore,
    Map<String, dynamic>? rules,
  }) async {
    final payload = <String, dynamic>{
      'rules': rules ?? {},
    };
    if (targetScore != null) {
      payload['target_score'] = targetScore;
    }

    final res = await _client.post(
      ApiEndpoints.startRoom(roomId),
      data: payload,
    );
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomModel> stopGame(String roomId) async {
    final res = await _client.post(ApiEndpoints.stopRoom(roomId));
    return RoomModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getGameState(String roomId) async {
    final res = await _client.get('${ApiEndpoints.room(roomId)}/game/state');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendGameAction(
    String roomId, {
    required String action,
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    int? tileIndex,
    String? side,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      if (cardId != null) 'card_id': cardId,
      if (chosenColor != null) 'chosen_color': chosenColor,
      if (targetPlayerId != null) 'target_player_id': targetPlayerId,
      if (tileIndex != null) 'tile_index': tileIndex,
      if (side != null) 'side': side,
      if (data != null) 'data': data,
    };

    final res = await _client.post(
      ApiEndpoints.roomAction(roomId),
      data: payload,
    );
    return res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : {};
  }
}
