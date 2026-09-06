import 'package:equatable/equatable.dart';

class ScopaCardModel extends Equatable {
  final String id;
  final String suit;
  final int value;

  const ScopaCardModel({
    required this.id,
    required this.suit,
    required this.value,
  });

  factory ScopaCardModel.fromJson(Map<String, dynamic> json) {
    return ScopaCardModel(
      id: json['id'] as String? ?? '',
      suit: json['suit'] as String? ?? '',
      value: json['value'] is int
          ? json['value'] as int
          : int.tryParse('${json['value']}') ?? 0,
    );
  }
  
  String get arabicName {
    String suitAr = suit;
    switch (suit) {
      case 'Diamonds':
        suitAr = 'ديناري';
        break;
      case 'Hearts':
        suitAr = 'قلب';
        break;
      case 'Spades':
        suitAr = 'بستوني';
        break;
      case 'Clubs':
        suitAr = 'شجرة';
        break;
    }
    String rankAr = value.toString();
    switch (value) {
      case 1:
        rankAr = 'آس';
        break;
      case 11:
        rankAr = 'جاك';
        break;
      case 12:
        rankAr = 'كوين';
        break;
      case 13:
        rankAr = 'ملك';
        break;
    }
    return '$rankAr من $suitAr';
  }

  @override
  List<Object?> get props => [id, suit, value];
}

class ScopaPlayerInfo extends Equatable {
  final int userId;
  final String name;
  final int score;
  final int handCount;

  const ScopaPlayerInfo({
    required this.userId,
    required this.name,
    required this.score,
    required this.handCount,
  });

  factory ScopaPlayerInfo.fromJson(Map<String, dynamic> json, Map<String, dynamic> handsCount) {
    final uid = json['user_id'] is int
        ? json['user_id'] as int
        : int.tryParse('${json['user_id']}') ?? 0;
    return ScopaPlayerInfo(
      userId: uid,
      name: json['name'] as String? ?? 'لاعب',
      score: json['score'] is int
          ? json['score'] as int
          : int.tryParse('${json['score']}') ?? 0,
      handCount: handsCount['$uid'] is int
          ? handsCount['$uid'] as int
          : int.tryParse('${handsCount['$uid']}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [userId, name, score, handCount];
}

class ScopaGameStateModel extends Equatable {
  final bool active;
  final String gameMode;
  final int targetScore;
  final int roundNumber;
  final int? currentTurnId;
  final String currentTurnName;
  final List<ScopaCardModel> tableCards;
  final int deckCount;
  final List<ScopaCardModel> myHand;
  final int myCapturedCount;
  final Map<String, int> scores;
  final bool isTeamGame;
  final Map<String, int> teams;
  final int? winnerId;
  final Map<String, dynamic>? pendingChoice;
  final String lastAction;
  final int? lastPlayerId;
  final int eventId;
  final String eventType;
  final String? soundCue;
  final List<ScopaPlayerInfo> players;
  final String roundSummary;

  const ScopaGameStateModel({
    required this.active,
    this.gameMode = 'classic',
    this.targetScore = 11,
    this.roundNumber = 0,
    this.currentTurnId,
    this.currentTurnName = '',
    this.tableCards = const [],
    this.deckCount = 0,
    this.myHand = const [],
    this.myCapturedCount = 0,
    this.scores = const {},
    this.isTeamGame = false,
    this.teams = const {},
    this.winnerId,
    this.pendingChoice,
    this.lastAction = '',
    this.lastPlayerId,
    this.eventId = 0,
    this.eventType = '',
    this.soundCue,
    this.players = const [],
    this.roundSummary = '',
  });

  bool isMyTurn(int myUserId) => currentTurnId == myUserId;

  factory ScopaGameStateModel.fromJson(Map<String, dynamic> json) {
    final rawTable = json['table_cards'] as List<dynamic>? ?? [];
    final parsedTable = rawTable.map((c) => ScopaCardModel.fromJson(c as Map<String, dynamic>)).toList();

    final rawHand = json['my_hand'] as List<dynamic>? ?? [];
    final parsedHand = rawHand.map((c) => ScopaCardModel.fromJson(c as Map<String, dynamic>)).toList();

    final handsCount = json['hands_count'] as Map<String, dynamic>? ?? {};

    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final parsedPlayers = rawPlayers
        .map((p) => ScopaPlayerInfo.fromJson(p as Map<String, dynamic>, handsCount))
        .toList();

    final rawScores = json['scores'] as Map<String, dynamic>? ?? {};
    final parsedScores = rawScores.map((key, value) => MapEntry(key, value is int ? value : int.tryParse('$value') ?? 0));

    final rawTeams = json['teams'] as Map<String, dynamic>? ?? {};
    final parsedTeams = rawTeams.map((key, value) => MapEntry(key, value is int ? value : int.tryParse('$value') ?? 0));

    return ScopaGameStateModel(
      active: json['active'] as bool? ?? false,
      gameMode: json['game_mode'] as String? ?? 'classic',
      targetScore: json['target_score'] is int ? json['target_score'] as int : int.tryParse('${json['target_score']}') ?? 11,
      roundNumber: json['round_number'] is int ? json['round_number'] as int : int.tryParse('${json['round_number']}') ?? 0,
      currentTurnId: json['current_turn_id'] as int?,
      currentTurnName: json['current_turn_name'] as String? ?? '',
      tableCards: parsedTable,
      deckCount: json['deck_count'] is int ? json['deck_count'] as int : int.tryParse('${json['deck_count']}') ?? 0,
      myHand: parsedHand,
      myCapturedCount: json['my_captured_count'] is int ? json['my_captured_count'] as int : int.tryParse('${json['my_captured_count']}') ?? 0,
      scores: parsedScores,
      isTeamGame: json['is_team_game'] as bool? ?? false,
      teams: parsedTeams,
      winnerId: json['winner_id'] as int?,
      pendingChoice: json['pending_choice'] as Map<String, dynamic>?,
      lastAction: json['last_action'] as String? ?? '',
      lastPlayerId: json['last_player_id'] as int?,
      eventId: json['event_id'] is int ? json['event_id'] as int : int.tryParse('${json['event_id']}') ?? 0,
      eventType: json['event_type'] as String? ?? '',
      soundCue: json['sound_cue'] as String?,
      players: parsedPlayers,
      roundSummary: json['round_summary'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        active,
        gameMode,
        targetScore,
        roundNumber,
        currentTurnId,
        currentTurnName,
        tableCards,
        deckCount,
        myHand,
        myCapturedCount,
        scores,
        isTeamGame,
        teams,
        winnerId,
        pendingChoice,
        lastAction,
        lastPlayerId,
        eventId,
        eventType,
        soundCue,
        players,
        roundSummary,
      ];
}
