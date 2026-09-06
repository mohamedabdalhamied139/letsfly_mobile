import 'package:equatable/equatable.dart';

/// Represents a multiplayer room on the Let's Fly platform.
class RoomModel extends Equatable {
  final String roomId;
  final int hostId;
  final String hostName;
  final String game;
  final String status;
  final List<int> players;
  final Map<int, String> playerNames;
  final Map<int, int> scores;
  final int? targetScore;
  final Map<String, dynamic> rules;

  const RoomModel({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.game,
    required this.status,
    required this.players,
    required this.playerNames,
    this.scores = const {},
    this.targetScore,
    this.rules = const {},
  });

  bool isHost(int userId) => hostId == userId;
  bool isPlaying() => status == 'playing';
  bool isWaiting() => status == 'waiting';

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    // Parse players
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final playersList = rawPlayers.map((p) {
      if (p is int) return p;
      return int.tryParse('$p') ?? 0;
    }).where((id) => id != 0).toList();

    // Parse player names safely (can be List from public_dict or Map from snapshot)
    final namesMap = <int, String>{};
    final rawNames = json['player_names'];
    if (rawNames is Map) {
      rawNames.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null) {
          namesMap[id] = '$v';
        }
      });
    } else if (rawNames is List) {
      for (int i = 0; i < rawNames.length && i < playersList.length; i++) {
        namesMap[playersList[i]] = '${rawNames[i]}';
      }
    }

    // Parse scores safely
    final scoresMap = <int, int>{};
    final rawScores = json['scores'];
    if (rawScores is Map) {
      rawScores.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null) {
          scoresMap[id] = v is int ? v : int.tryParse('$v') ?? 0;
        }
      });
    }

    return RoomModel(
      roomId: json['room_id'] as String? ?? json['id'] as String? ?? '',
      hostId: json['host_id'] is int
          ? json['host_id'] as int
          : int.tryParse('${json['host_id']}') ?? 0,
      hostName: json['host_name'] as String? ?? '',
      game: (json['game'] as String? ?? 'UNO').toUpperCase(),
      status: json['status'] as String? ?? 'waiting',
      players: playersList,
      playerNames: namesMap,
      scores: scoresMap,
      targetScore: json['target_score'] as int?,
      rules: json['rules'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'host_id': hostId,
      'host_name': hostName,
      'game': game,
      'status': status,
      'players': players,
      'player_names': playerNames.map((k, v) => MapEntry(k.toString(), v)),
      'scores': scores.map((k, v) => MapEntry(k.toString(), v)),
      'target_score': targetScore,
      'rules': rules,
    };
  }

  @override
  List<Object?> get props => [
        roomId,
        hostId,
        hostName,
        game,
        status,
        players,
        playerNames,
        scores,
        targetScore,
        rules,
      ];
}

/// Type alias mapping RoomSummary directly to RoomModel for PROJECT.md contract compliance.
typedef RoomSummary = RoomModel;
