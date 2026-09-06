import 'package:equatable/equatable.dart';
import 'ninety_nine_card_model.dart';

class NinetyNineGameStateModel extends Equatable {
  final String gameType;
  final int eventId;
  final String eventType;
  final String lastAction;
  final String? soundCue;
  final bool active;
  final int? winnerId;
  final int pileValue;
  final bool roundFinished;
  final int currentTurnIndex;
  final int? currentTurnId;
  final int? currentPlayerId;
  final String currentPlayerName;
  final int direction;
  final Map<int, int> tokens;
  final List<int> eliminated;
  final Map<String, dynamic>? pendingChoice;
  final List<dynamic> players;
  final List<NinetyNineCardModel> hand;

  const NinetyNineGameStateModel({
    required this.gameType,
    required this.eventId,
    required this.eventType,
    required this.lastAction,
    this.soundCue,
    required this.active,
    this.winnerId,
    required this.pileValue,
    required this.roundFinished,
    required this.currentTurnIndex,
    this.currentTurnId,
    this.currentPlayerId,
    required this.currentPlayerName,
    required this.direction,
    required this.tokens,
    required this.eliminated,
    this.pendingChoice,
    required this.players,
    required this.hand,
  });

  factory NinetyNineGameStateModel.fromJson(Map<String, dynamic> json) {
    return NinetyNineGameStateModel(
      gameType: json['game_type'] as String? ?? 'NINETY_NINE',
      eventId: json['event_id'] as int? ?? 0,
      eventType: json['event_type'] as String? ?? '',
      lastAction: json['last_action'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      active: json['active'] as bool? ?? false,
      winnerId: json['winner_id'] as int?,
      pileValue: json['pile_value'] as int? ?? 0,
      roundFinished: json['round_finished'] as bool? ?? false,
      currentTurnIndex: json['current_turn_index'] as int? ?? 0,
      currentTurnId: json['current_turn_id'] as int?,
      currentPlayerId: json['current_player_id'] as int?,
      currentPlayerName: json['current_player_name'] as String? ?? '',
      direction: json['direction'] as int? ?? 1,
      tokens: (json['tokens'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(int.tryParse(key) ?? 0, value as int),
          ) ??
          {},
      eliminated: (json['eliminated'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      pendingChoice: json['pending_choice'] as Map<String, dynamic>?,
      players: json['players'] as List<dynamic>? ?? [],
      hand: (json['hand'] as List<dynamic>?)
              ?.map((e) => NinetyNineCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool isMyTurn(int myUserId) {
    return active && (currentPlayerId == myUserId);
  }

  @override
  List<Object?> get props => [
        gameType,
        eventId,
        eventType,
        lastAction,
        soundCue,
        active,
        winnerId,
        pileValue,
        roundFinished,
        currentTurnIndex,
        currentTurnId,
        currentPlayerId,
        currentPlayerName,
        direction,
        tokens,
        eliminated,
        pendingChoice,
        players,
        hand,
      ];
}
