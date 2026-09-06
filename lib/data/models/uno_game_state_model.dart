import 'package:equatable/equatable.dart';
import 'uno_card_model.dart';

/// Opponent / Player info at the UNO table.
class UnoPlayerInfo extends Equatable {
  final int userId;
  final String name;
  final int cardCount;
  final bool eliminated;

  const UnoPlayerInfo({
    required this.userId,
    required this.name,
    required this.cardCount,
    this.eliminated = false,
  });

  factory UnoPlayerInfo.fromJson(Map<String, dynamic> json) {
    return UnoPlayerInfo(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id']}') ?? 0,
      name: json['name'] as String? ?? 'لاعب',
      cardCount: json['card_count'] is int
          ? json['card_count'] as int
          : int.tryParse('${json['card_count']}') ?? 0,
      eliminated: json['eliminated'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [userId, name, cardCount, eliminated];
}

/// Full synchronized state of an active UNO game session.
class UnoGameStateModel extends Equatable {
  final bool active;
  final int? winnerId;
  final int? currentPlayerId;
  final String currentPlayerName;
  final String currentColor;
  final UnoCardModel? topCard;
  final List<UnoCardModel> hand;
  final String? drawnCardId;
  final List<UnoPlayerInfo> players;
  final List<int> pendingUnoPlayers;
  final int roundScore;
  final int targetScore;
  final String lastAction;
  final int eventId;
  final String eventType;
  final String? soundCue;
  final int pendingDrawCount;
  final bool buzzerPending;
  final Map<String, dynamic>? pendingBluff;
  final bool darkSide;

  const UnoGameStateModel({
    required this.active,
    this.winnerId,
    this.currentPlayerId,
    this.currentPlayerName = '',
    this.currentColor = '',
    this.topCard,
    this.hand = const [],
    this.drawnCardId,
    this.players = const [],
    this.pendingUnoPlayers = const [],
    this.roundScore = 0,
    this.targetScore = 500,
    this.lastAction = '',
    this.eventId = 0,
    this.eventType = '',
    this.soundCue,
    this.pendingDrawCount = 0,
    this.buzzerPending = false,
    this.pendingBluff,
    this.darkSide = false,
  });

  bool isMyTurn(int myUserId) => currentPlayerId == myUserId;

  bool canPlayAnyCard() {
    return hand.any((c) => c.isPlayable(topCard, currentColor));
  }

  factory UnoGameStateModel.fromJson(Map<String, dynamic> json) {
    // Parse hand
    final rawHand = json['hand'] as List<dynamic>? ?? [];
    final parsedHand = rawHand
        .map((c) => UnoCardModel.fromJson(c as Map<String, dynamic>))
        .toList();

    // Parse top card
    final rawTop = json['top_card'];
    final parsedTop = rawTop is Map<String, dynamic>
        ? UnoCardModel.fromJson(rawTop)
        : null;

    // Parse players
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final parsedPlayers = rawPlayers
        .map((p) => UnoPlayerInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    // Parse pending UNO players
    final rawPendingUno = json['pending_uno_players'] as List<dynamic>? ?? [];
    final parsedPendingUno = rawPendingUno.map((p) {
      if (p is Map<String, dynamic>) {
        return p['user_id'] is int
            ? p['user_id'] as int
            : int.tryParse('${p['user_id']}') ?? 0;
      }
      return int.tryParse('$p') ?? 0;
    }).where((id) => id != 0).toList();

    return UnoGameStateModel(
      active: json['active'] as bool? ?? false,
      winnerId: json['winner_id'] as int?,
      currentPlayerId: json['current_player_id'] as int?,
      currentPlayerName: json['current_player_name'] as String? ?? '',
      currentColor: json['current_color'] as String? ?? '',
      topCard: parsedTop,
      hand: parsedHand,
      drawnCardId: json['drawn_card_id'] as String?,
      players: parsedPlayers,
      pendingUnoPlayers: parsedPendingUno,
      roundScore: json['round_score'] is int
          ? json['round_score'] as int
          : int.tryParse('${json['round_score']}') ?? 0,
      targetScore: json['target_score'] is int
          ? json['target_score'] as int
          : int.tryParse('${json['target_score']}') ?? 500,
      lastAction: json['last_action'] as String? ?? '',
      eventId: json['event_id'] is int
          ? json['event_id'] as int
          : int.tryParse('${json['event_id']}') ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      pendingDrawCount: json['pending_draw_count'] is int
          ? json['pending_draw_count'] as int
          : int.tryParse('${json['pending_draw_count']}') ?? 0,
      buzzerPending: json['buzzer_pending'] as bool? ?? false,
      pendingBluff: json['pending_bluff'] as Map<String, dynamic>?,
      darkSide: json['dark_side'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        active,
        winnerId,
        currentPlayerId,
        currentPlayerName,
        currentColor,
        topCard,
        hand,
        drawnCardId,
        players,
        pendingUnoPlayers,
        roundScore,
        targetScore,
        lastAction,
        eventId,
        eventType,
        soundCue,
        pendingDrawCount,
        buzzerPending,
        pendingBluff,
        darkSide,
      ];
}
