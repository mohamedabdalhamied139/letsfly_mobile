import 'package:equatable/equatable.dart';

class DominoPlayerInfo extends Equatable {
  final int userId;
  final String name;
  final int tileCount;
  final int score;

  const DominoPlayerInfo({
    required this.userId,
    required this.name,
    required this.tileCount,
    required this.score,
  });

  factory DominoPlayerInfo.fromJson(Map<String, dynamic> json) {
    return DominoPlayerInfo(
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse('${json['user_id']}') ?? 0,
      name: json['name'] as String? ?? 'لاعب',
      tileCount: json['tile_count'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [userId, name, tileCount, score];
}

class DominoHandTile extends Equatable {
  final int index;
  final List<int> tile;
  final String label;
  final bool isValid;
  final List<String> validSides;

  const DominoHandTile({
    required this.index,
    required this.tile,
    required this.label,
    required this.isValid,
    required this.validSides,
  });

  factory DominoHandTile.fromJson(Map<String, dynamic> json) {
    return DominoHandTile(
      index: json['index'] as int? ?? 0,
      tile: (json['tile'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      label: json['label'] as String? ?? '',
      isValid: json['is_valid'] as bool? ?? false,
      validSides: (json['valid_sides'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
  
  @override
  List<Object?> get props => [index, tile, label, isValid, validSides];
}

class DominoGameStateModel extends Equatable {
  final bool active;
  final int roundNumber;
  final int targetScore;
  final Map<String, int> scores;
  final Map<String, String> playerNames;
  final List<DominoPlayerInfo> players;
  final int? currentPlayerId;
  final String currentPlayerName;
  final bool isMyTurn;
  final int? leftEnd;
  final int? rightEnd;
  final List<List<int>> board;
  final int boardCount;
  final int boneyardCount;
  final List<DominoHandTile> hand;
  final bool canDraw;
  final bool canPass;
  final int? winnerId;
  final int? roundWinnerId;
  final int roundPointsWon;
  final int eventId;
  final String eventType;
  final String? soundCue;
  final String lastAction;
  
  // specific to American Domino
  final int? openEndsSum;
  final String? scoringMode;

  const DominoGameStateModel({
    required this.active,
    this.roundNumber = 0,
    this.targetScore = 100,
    this.scores = const {},
    this.playerNames = const {},
    this.players = const [],
    this.currentPlayerId,
    this.currentPlayerName = '',
    this.isMyTurn = false,
    this.leftEnd,
    this.rightEnd,
    this.board = const [],
    this.boardCount = 0,
    this.boneyardCount = 0,
    this.hand = const [],
    this.canDraw = false,
    this.canPass = false,
    this.winnerId,
    this.roundWinnerId,
    this.roundPointsWon = 0,
    this.eventId = 0,
    this.eventType = '',
    this.soundCue,
    this.lastAction = '',
    this.openEndsSum,
    this.scoringMode,
  });

  factory DominoGameStateModel.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    final parsedScores = rawScores.map((k, v) => MapEntry(k, v as int? ?? 0));
    
    final rawNames = json['player_names'] as Map<String, dynamic>? ?? {};
    final parsedNames = rawNames.map((k, v) => MapEntry(k, v.toString()));

    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final parsedPlayers = rawPlayers.map((p) => DominoPlayerInfo.fromJson(p as Map<String, dynamic>)).toList();

    final rawHand = json['hand'] as List<dynamic>? ?? [];
    final parsedHand = rawHand.map((t) => DominoHandTile.fromJson(t as Map<String, dynamic>)).toList();

    final rawBoard = json['board'] as List<dynamic>? ?? [];
    final parsedBoard = rawBoard.map((row) => (row as List<dynamic>).map((e) => e as int).toList()).toList();

    return DominoGameStateModel(
      active: json['active'] as bool? ?? false,
      roundNumber: json['round_number'] as int? ?? 0,
      targetScore: json['target_score'] as int? ?? 100,
      scores: parsedScores,
      playerNames: parsedNames,
      players: parsedPlayers,
      currentPlayerId: json['current_player_id'] as int?,
      currentPlayerName: json['current_player_name'] as String? ?? '',
      isMyTurn: json['is_my_turn'] as bool? ?? false,
      leftEnd: json['left_end'] as int?,
      rightEnd: json['right_end'] as int?,
      board: parsedBoard,
      boardCount: json['board_count'] as int? ?? 0,
      boneyardCount: json['boneyard_count'] as int? ?? 0,
      hand: parsedHand,
      canDraw: json['can_draw'] as bool? ?? false,
      canPass: json['can_pass'] as bool? ?? false,
      winnerId: json['winner_id'] as int?,
      roundWinnerId: json['round_winner_id'] as int?,
      roundPointsWon: json['round_points_won'] as int? ?? 0,
      eventId: json['event_id'] as int? ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      lastAction: json['last_action'] as String? ?? '',
      openEndsSum: json['open_ends_sum'] as int?,
      scoringMode: json['scoring_mode'] as String?,
    );
  }
  
  @override
  List<Object?> get props => [
    active, roundNumber, targetScore, scores, playerNames, players, currentPlayerId,
    currentPlayerName, isMyTurn, leftEnd, rightEnd, board, boardCount, boneyardCount,
    hand, canDraw, canPass, winnerId, roundWinnerId, roundPointsWon, eventId, eventType,
    soundCue, lastAction, openEndsSum, scoringMode
  ];
}
