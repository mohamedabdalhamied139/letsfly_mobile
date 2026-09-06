import 'package:equatable/equatable.dart';

class FarkleCombination extends Equatable {
  final String type;
  final List<int> indices;
  final List<int> vals;
  final int points;
  final String label;
  final String labelEn;

  const FarkleCombination({
    required this.type,
    required this.indices,
    required this.vals,
    required this.points,
    required this.label,
    required this.labelEn,
  });

  factory FarkleCombination.fromJson(Map<String, dynamic> json) {
    return FarkleCombination(
      type: json['type'] as String? ?? '',
      indices: (json['indices'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      vals: (json['vals'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      points: json['points'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      labelEn: json['label_en'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [type, indices, vals, points, label, labelEn];
}

class FarkleStateModel extends Equatable {
  final bool active;
  final int? winnerId;
  final int targetScore;
  final int minBank;
  final int firstBankMin;
  final int? currentPlayerId;
  final String currentPlayerName;
  final Map<String, int> scores;
  final Map<String, String> playerNames;
  final List<int> dice;
  final List<int> availableIndices;
  final List<FarkleCombination> availableCombinations;
  final int turnScore;
  final List<int> lastRoll;
  final int eventId;
  final String eventType;
  final String? soundCue;
  final String lastAction;
  final bool isMyTurn;
  final bool canRoll;
  final bool mustScoreBeforeRoll;

  const FarkleStateModel({
    required this.active,
    this.winnerId,
    this.targetScore = 1500,
    this.minBank = 300,
    this.firstBankMin = 1000,
    this.currentPlayerId,
    this.currentPlayerName = '',
    this.scores = const {},
    this.playerNames = const {},
    this.dice = const [],
    this.availableIndices = const [],
    this.availableCombinations = const [],
    this.turnScore = 0,
    this.lastRoll = const [],
    this.eventId = 0,
    this.eventType = '',
    this.soundCue,
    this.lastAction = '',
    this.isMyTurn = false,
    this.canRoll = false,
    this.mustScoreBeforeRoll = false,
  });

  factory FarkleStateModel.fromJson(Map<String, dynamic> json) {
    return FarkleStateModel(
      active: json['active'] as bool? ?? false,
      winnerId: json['winner_id'] as int?,
      targetScore: json['target_score'] as int? ?? 1500,
      minBank: json['min_bank'] as int? ?? 300,
      firstBankMin: json['first_bank_min'] as int? ?? 1000,
      currentPlayerId: json['current_player_id'] as int?,
      currentPlayerName: json['current_player_name'] as String? ?? '',
      scores: (json['scores'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
      playerNames: (json['player_names'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      dice: (json['dice'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      availableIndices: (json['available_indices'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      availableCombinations: (json['available_combinations'] as List<dynamic>?)
              ?.map((e) => FarkleCombination.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      turnScore: json['turn_score'] as int? ?? 0,
      lastRoll: (json['last_roll'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      eventId: (json['event_id'] is int) ? (json['event_id'] as int) : int.tryParse(json['event_id'].toString()) ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      lastAction: json['last_action'] as String? ?? '',
      isMyTurn: json['is_my_turn'] as bool? ?? false,
      canRoll: json['can_roll'] as bool? ?? false,
      mustScoreBeforeRoll: json['must_score_before_roll'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        active,
        winnerId,
        targetScore,
        minBank,
        firstBankMin,
        currentPlayerId,
        currentPlayerName,
        scores,
        playerNames,
        dice,
        availableIndices,
        availableCombinations,
        turnScore,
        lastRoll,
        eventId,
        eventType,
        soundCue,
        lastAction,
        isMyTurn,
        canRoll,
        mustScoreBeforeRoll,
      ];
}
