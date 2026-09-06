import 'package:equatable/equatable.dart';

class SnakesAndLaddersPlayerInfo extends Equatable {
  final int userId;
  final String name;
  final int position;
  final bool isFrozen;
  final bool hasShield;
  final int distanceToFinish;

  const SnakesAndLaddersPlayerInfo({
    required this.userId,
    required this.name,
    required this.position,
    this.isFrozen = false,
    this.hasShield = false,
    required this.distanceToFinish,
  });

  factory SnakesAndLaddersPlayerInfo.fromJson(Map<String, dynamic> json) {
    return SnakesAndLaddersPlayerInfo(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse('${json['user_id']}') ?? 0,
      name: json['name'] as String? ?? 'لاعب',
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse('${json['position']}') ?? 0,
      isFrozen: json['is_frozen'] as bool? ?? false,
      hasShield: json['has_shield'] as bool? ?? false,
      distanceToFinish: json['distance_to_finish'] is int
          ? json['distance_to_finish'] as int
          : int.tryParse('${json['distance_to_finish']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        position,
        isFrozen,
        hasShield,
        distanceToFinish,
      ];
}

class SnakesAndLaddersRadarEntity extends Equatable {
  final int start;
  final int end;
  final int distance;

  const SnakesAndLaddersRadarEntity({
    required this.start,
    required this.end,
    required this.distance,
  });

  factory SnakesAndLaddersRadarEntity.fromList(List<dynamic> list) {
    return SnakesAndLaddersRadarEntity(
      start: list.isNotEmpty ? (list[0] as num).toInt() : 0,
      end: list.length > 1 ? (list[1] as num).toInt() : 0,
      distance: list.length > 2 ? (list[2] as num).toInt() : 0,
    );
  }

  @override
  List<Object?> get props => [start, end, distance];
}

class SnakesAndLaddersRadar extends Equatable {
  final int position;
  final SnakesAndLaddersRadarEntity? nearestLadder;
  final SnakesAndLaddersRadarEntity? nearestSnake;
  final int distanceToFinish;

  const SnakesAndLaddersRadar({
    required this.position,
    this.nearestLadder,
    this.nearestSnake,
    required this.distanceToFinish,
  });

  factory SnakesAndLaddersRadar.fromJson(Map<String, dynamic> json) {
    final ladder = json['nearest_ladder'] as List<dynamic>?;
    final snake = json['nearest_snake'] as List<dynamic>?;

    return SnakesAndLaddersRadar(
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse('${json['position']}') ?? 0,
      nearestLadder:
          ladder != null ? SnakesAndLaddersRadarEntity.fromList(ladder) : null,
      nearestSnake:
          snake != null ? SnakesAndLaddersRadarEntity.fromList(snake) : null,
      distanceToFinish: json['distance_to_finish'] is int
          ? json['distance_to_finish'] as int
          : int.tryParse('${json['distance_to_finish']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        position,
        nearestLadder,
        nearestSnake,
        distanceToFinish,
      ];
}

class SnakesAndLaddersStateModel extends Equatable {
  final bool active;
  final Map<String, dynamic> rules;
  final List<SnakesAndLaddersPlayerInfo> players;
  final Map<String, int> positions;
  final Map<String, String> playerNames;
  final int? currentPlayerId;
  final String currentPlayerName;
  final bool isMyTurn;
  final int lastRoll;
  final bool extraRoll;
  final int? winnerId;
  final SnakesAndLaddersRadar? radar;
  final int eventId;
  final String eventType;
  final String soundCue;
  final List<String> soundCues;
  final String lastAction;
  final String rollAction;
  final String arrivalAction;

  const SnakesAndLaddersStateModel({
    required this.active,
    this.rules = const {},
    this.players = const [],
    this.positions = const {},
    this.playerNames = const {},
    this.currentPlayerId,
    this.currentPlayerName = '',
    this.isMyTurn = false,
    this.lastRoll = 0,
    this.extraRoll = false,
    this.winnerId,
    this.radar,
    this.eventId = 0,
    this.eventType = '',
    this.soundCue = '',
    this.soundCues = const [],
    this.lastAction = '',
    this.rollAction = '',
    this.arrivalAction = '',
  });

  factory SnakesAndLaddersStateModel.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final parsedPlayers = rawPlayers
        .map((p) =>
            SnakesAndLaddersPlayerInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    final Map<String, int> parsedPositions = {};
    if (json['positions'] is Map) {
      final posMap = json['positions'] as Map;
      posMap.forEach((key, value) {
        parsedPositions[key.toString()] =
            value is int ? value : int.tryParse('$value') ?? 0;
      });
    }

    final Map<String, String> parsedNames = {};
    if (json['player_names'] is Map) {
      final nameMap = json['player_names'] as Map;
      nameMap.forEach((key, value) {
        parsedNames[key.toString()] = value.toString();
      });
    }

    final radarData = json['radar'] as Map<String, dynamic>?;

    final rawSoundCues = json['sound_cues'] as List<dynamic>? ?? [];
    final parsedSoundCues = rawSoundCues.map((e) => e.toString()).toList();

    return SnakesAndLaddersStateModel(
      active: json['active'] as bool? ?? false,
      rules: json['rules'] as Map<String, dynamic>? ?? {},
      players: parsedPlayers,
      positions: parsedPositions,
      playerNames: parsedNames,
      currentPlayerId: json['current_player_id'] as int?,
      currentPlayerName: json['current_player_name'] as String? ?? '',
      isMyTurn: json['is_my_turn'] as bool? ?? false,
      lastRoll: json['last_roll'] is int
          ? json['last_roll'] as int
          : int.tryParse('${json['last_roll']}') ?? 0,
      extraRoll: json['extra_roll'] as bool? ?? false,
      winnerId: json['winner_id'] as int?,
      radar: radarData != null ? SnakesAndLaddersRadar.fromJson(radarData) : null,
      eventId: json['event_id'] is int
          ? json['event_id'] as int
          : int.tryParse('${json['event_id']}') ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String? ?? '',
      soundCues: parsedSoundCues,
      lastAction: json['last_action'] as String? ?? '',
      rollAction: json['roll_action'] as String? ?? '',
      arrivalAction: json['arrival_action'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        active,
        rules,
        players,
        positions,
        playerNames,
        currentPlayerId,
        currentPlayerName,
        isMyTurn,
        lastRoll,
        extraRoll,
        winnerId,
        radar,
        eventId,
        eventType,
        soundCue,
        soundCues,
        lastAction,
        rollAction,
        arrivalAction,
      ];
}
