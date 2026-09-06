import '../datasources/room_remote_datasource.dart';
import '../models/room_model.dart';

abstract class RoomRepository {
  Future<List<RoomModel>> getRooms();
  Future<RoomModel> createRoom({String game = 'UNO'});
  Future<RoomModel> getRoom(String roomId);
  Future<RoomModel> joinRoom(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<RoomModel> addBot(String roomId);
  Future<void> removeBot(String roomId);
  Future<RoomModel> startGame(String roomId, {int? targetScore, Map<String, dynamic>? rules});
  Future<RoomModel> stopGame(String roomId);
  Future<Map<String, dynamic>> getGameState(String roomId);
  Future<Map<String, dynamic>> sendGameAction(
    String roomId, {
    required String action,
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    int? tileIndex,
    String? side,
    Map<String, dynamic>? data,
  });
}

class RoomRepositoryImpl implements RoomRepository {
  final RoomRemoteDataSource _remoteDataSource;

  RoomRepositoryImpl({required RoomRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<RoomModel>> getRooms() => _remoteDataSource.listRooms();

  @override
  Future<RoomModel> createRoom({String game = 'UNO'}) =>
      _remoteDataSource.createRoom(game: game);

  @override
  Future<RoomModel> getRoom(String roomId) => _remoteDataSource.getRoom(roomId);

  @override
  Future<RoomModel> joinRoom(String roomId) => _remoteDataSource.joinRoom(roomId);

  @override
  Future<void> leaveRoom(String roomId) => _remoteDataSource.leaveRoom(roomId);

  @override
  Future<RoomModel> addBot(String roomId) => _remoteDataSource.addBot(roomId);

  @override
  Future<void> removeBot(String roomId) => _remoteDataSource.removeBot(roomId);

  @override
  Future<RoomModel> startGame(
    String roomId, {
    int? targetScore,
    Map<String, dynamic>? rules,
  }) =>
      _remoteDataSource.startGame(roomId, targetScore: targetScore, rules: rules);

  @override
  Future<RoomModel> stopGame(String roomId) => _remoteDataSource.stopGame(roomId);

  @override
  Future<Map<String, dynamic>> getGameState(String roomId) =>
      _remoteDataSource.getGameState(roomId);

  @override
  Future<Map<String, dynamic>> sendGameAction(
    String roomId, {
    required String action,
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    int? tileIndex,
    String? side,
    Map<String, dynamic>? data,
  }) =>
      _remoteDataSource.sendGameAction(
        roomId,
        action: action,
        cardId: cardId,
        chosenColor: chosenColor,
        targetPlayerId: targetPlayerId,
        tileIndex: tileIndex,
        side: side,
        data: data,
      );
}
