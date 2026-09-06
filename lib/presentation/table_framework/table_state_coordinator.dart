import 'dart:async';
import '../../core/network/ws_client.dart';
import '../../data/models/game_state_model.dart';
import '../../data/repositories/room_repository.dart';
import '../../data/repositories/room_ws_service.dart';

/// Shared table lifecycle coordinator. Game screens must not implement their
/// own REST/WS lifecycle; they consume this coordinator through the shell.
class TableStateCoordinator {
  final RoomRepository repository;
  final RoomWsService ws;
  final String roomId;

  const TableStateCoordinator({
    required this.repository,
    required this.ws,
    required this.roomId,
  });

  WsConnectionState get connectionState => ws.state;

  Stream<GameStateModel> get gameStates => ws.snapshotStream
      .map((snapshot) {
        final raw = snapshot.gameState;
        if (raw is GameStateModel) return raw;
        if (raw is Map<String, dynamic>) {
          return GameStateModel(
            game: snapshot.gameType ?? snapshot.room.game,
            data: raw,
          );
        }
        if (raw is Map) {
          return GameStateModel(
            game: snapshot.gameType ?? snapshot.room.game,
            data: Map<String, dynamic>.from(raw),
          );
        }
        return null;
      })
      .where((e) => e != null)
      .cast<GameStateModel>();

  Future<Map<String, dynamic>> fetchGameState() => repository.getGameState(roomId);

  Future<void> sendAction(
    String action, {
    String? cardId,
    String? chosenColor,
    String? targetPlayerId,
    String? side,
    Map<String, dynamic>? data,
  }) {
    if (ws.state == WsConnectionState.connected) {
      return ws.sendGameAction(
        action,
        cardId: cardId,
        chosenColor: chosenColor,
        targetPlayerId: targetPlayerId,
        side: side,
        data: data,
      );
    }

    return repository
        .sendGameAction(
          roomId,
          action: action,
          cardId: cardId,
          chosenColor: chosenColor,
          targetPlayerId: targetPlayerId,
          side: side,
          data: data,
        )
        .then((_) {});
  }
}
