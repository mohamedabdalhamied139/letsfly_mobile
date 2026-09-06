import 'package:equatable/equatable.dart';

class ThiefHuntPlayer extends Equatable {
  final int userId;
  final String name;
  final int wins;
  final bool active;
  final bool eliminated;
  final bool isThief;

  const ThiefHuntPlayer({
    required this.userId,
    required this.name,
    required this.wins,
    required this.active,
    required this.eliminated,
    required this.isThief,
  });

  factory ThiefHuntPlayer.fromJson(Map<String, dynamic> json) {
    return ThiefHuntPlayer(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'لاعب',
      wins: json['wins'] as int? ?? 0,
      active: json['active'] as bool? ?? false,
      eliminated: json['eliminated'] as bool? ?? false,
      isThief: json['is_thief'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [userId, name, wins, active, eliminated, isThief];
}

class ThiefHuntAnswer extends Equatable {
  final int userId;
  final String name;
  final int floor;

  const ThiefHuntAnswer({
    required this.userId,
    required this.name,
    required this.floor,
  });

  factory ThiefHuntAnswer.fromJson(Map<String, dynamic> json) {
    return ThiefHuntAnswer(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      floor: json['floor'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [userId, name, floor];
}

class ThiefHuntStateModel extends Equatable {
  final bool active;
  final String phase;
  final int roundNumber;
  final int totalRounds;
  final int playedRounds;
  final bool suddenDeath;
  final bool eliminationMode;
  final Map<String, int> roundScores;
  final int roundsWonTotal;
  final int directionDuration;
  final int eventId;
  final String eventType;
  final String? soundCue;
  final String lastAction;
  final String thiefName;
  final int? thiefId;
  final bool thiefVirtual;
  final bool isThief;
  final int? startFloor;
  final List<String> directions;
  final int? finalFloor;
  final int answerSecondsRemaining;
  final List<ThiefHuntAnswer> answers;
  final List<int> roundWinners;
  final String roundWinnerType;
  final int? roundWinnerId;
  final String roundWinnerName;
  final int virtualThiefWins;
  final int? matchWinnerId;
  final String matchWinnerName;
  final String matchWinnerType;
  final List<ThiefHuntPlayer> players;

  const ThiefHuntStateModel({
    required this.active,
    required this.phase,
    required this.roundNumber,
    required this.totalRounds,
    required this.playedRounds,
    required this.suddenDeath,
    required this.eliminationMode,
    required this.roundScores,
    required this.roundsWonTotal,
    required this.directionDuration,
    required this.eventId,
    required this.eventType,
    this.soundCue,
    required this.lastAction,
    required this.thiefName,
    this.thiefId,
    required this.thiefVirtual,
    required this.isThief,
    this.startFloor,
    this.directions = const [],
    this.finalFloor,
    required this.answerSecondsRemaining,
    this.answers = const [],
    this.roundWinners = const [],
    required this.roundWinnerType,
    this.roundWinnerId,
    required this.roundWinnerName,
    required this.virtualThiefWins,
    this.matchWinnerId,
    required this.matchWinnerName,
    required this.matchWinnerType,
    this.players = const [],
  });

  factory ThiefHuntStateModel.fromJson(Map<String, dynamic> json) {
    final rawScores = json['round_scores'] as Map<String, dynamic>? ?? {};
    final scores = rawScores.map((k, v) => MapEntry(k, v as int? ?? 0));

    final rawDirections = json['directions'] as List<dynamic>? ?? [];
    final dirs = rawDirections.map((d) => d.toString()).toList();

    final rawAnswers = json['answers'] as List<dynamic>? ?? [];
    final parsedAnswers = rawAnswers
        .map((a) => ThiefHuntAnswer.fromJson(a as Map<String, dynamic>))
        .toList();

    final rawWinners = json['round_winners'] as List<dynamic>? ?? [];
    final roundWin = rawWinners.map((w) => w as int).toList();

    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final parsedPlayers = rawPlayers
        .map((p) => ThiefHuntPlayer.fromJson(p as Map<String, dynamic>))
        .toList();

    return ThiefHuntStateModel(
      active: json['active'] as bool? ?? false,
      phase: json['phase'] as String? ?? 'waiting',
      roundNumber: json['round_number'] as int? ?? 0,
      totalRounds: json['total_rounds'] as int? ?? 0,
      playedRounds: json['played_rounds'] as int? ?? 0,
      suddenDeath: json['sudden_death'] as bool? ?? false,
      eliminationMode: json['elimination_mode'] as bool? ?? false,
      roundScores: scores,
      roundsWonTotal: json['rounds_won_total'] as int? ?? 0,
      directionDuration: json['direction_duration'] as int? ?? 0,
      eventId: json['event_id'] as int? ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      lastAction: json['last_action'] as String? ?? '',
      thiefName: json['thief_name'] as String? ?? '',
      thiefId: json['thief_id'] as int?,
      thiefVirtual: json['thief_virtual'] as bool? ?? false,
      isThief: json['is_thief'] as bool? ?? false,
      startFloor: json['start_floor'] as int?,
      directions: dirs,
      finalFloor: json['final_floor'] as int?,
      answerSecondsRemaining: json['answer_seconds_remaining'] as int? ?? 0,
      answers: parsedAnswers,
      roundWinners: roundWin,
      roundWinnerType: json['round_winner_type'] as String? ?? '',
      roundWinnerId: json['round_winner_id'] as int?,
      roundWinnerName: json['round_winner_name'] as String? ?? '',
      virtualThiefWins: json['virtual_thief_wins'] as int? ?? 0,
      matchWinnerId: json['match_winner_id'] as int?,
      matchWinnerName: json['match_winner_name'] as String? ?? '',
      matchWinnerType: json['match_winner_type'] as String? ?? '',
      players: parsedPlayers,
    );
  }

  @override
  List<Object?> get props => [
        active,
        phase,
        roundNumber,
        totalRounds,
        playedRounds,
        suddenDeath,
        eliminationMode,
        roundScores,
        roundsWonTotal,
        directionDuration,
        eventId,
        eventType,
        soundCue,
        lastAction,
        thiefName,
        thiefId,
        thiefVirtual,
        isThief,
        startFloor,
        directions,
        finalFloor,
        answerSecondsRemaining,
        answers,
        roundWinners,
        roundWinnerType,
        roundWinnerId,
        roundWinnerName,
        virtualThiefWins,
        matchWinnerId,
        matchWinnerName,
        matchWinnerType,
        players,
      ];
}
