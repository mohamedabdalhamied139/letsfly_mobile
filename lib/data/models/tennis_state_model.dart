import 'package:equatable/equatable.dart';

class TennisScoreModel extends Equatable {
  final Map<int, String> points;
  final Map<int, int> games;
  final Map<int, int> sets;
  final int serverIdx;
  final bool tiebreak;
  final Map<int, int> tiebreakPoints;

  const TennisScoreModel({
    required this.points,
    required this.games,
    required this.sets,
    required this.serverIdx,
    required this.tiebreak,
    required this.tiebreakPoints,
  });

  factory TennisScoreModel.fromJson(Map<String, dynamic> json) {
    Map<int, String> _parsePoints(dynamic data) {
      if (data is Map) {
        return {
          0: data['0']?.toString() ?? '0',
          1: data['1']?.toString() ?? '0',
        };
      }
      return {0: '0', 1: '0'};
    }

    Map<int, int> _parseIntMap(dynamic data) {
      if (data is Map) {
        return {
          0: data['0'] is int ? data['0'] : int.tryParse(data['0'].toString()) ?? 0,
          1: data['1'] is int ? data['1'] : int.tryParse(data['1'].toString()) ?? 0,
        };
      }
      return {0: 0, 1: 0};
    }

    return TennisScoreModel(
      points: _parsePoints(json['points']),
      games: _parseIntMap(json['games']),
      sets: _parseIntMap(json['sets']),
      serverIdx: json['server_idx'] as int? ?? 0,
      tiebreak: json['tiebreak'] as bool? ?? false,
      tiebreakPoints: _parseIntMap(json['tiebreak_points']),
    );
  }

  @override
  List<Object?> get props => [points, games, sets, serverIdx, tiebreak, tiebreakPoints];
}

class TennisBallModel extends Equatable {
  final int target;
  final int direction;
  final double launchTime;
  final double travelTime;
  final double netTime;
  final double floorTime;
  final double reachTime;

  const TennisBallModel({
    required this.target,
    required this.direction,
    required this.launchTime,
    required this.travelTime,
    required this.netTime,
    required this.floorTime,
    required this.reachTime,
  });

  factory TennisBallModel.fromJson(Map<String, dynamic> json) {
    return TennisBallModel(
      target: json['target'] as int? ?? 0,
      direction: json['direction'] as int? ?? 1,
      launchTime: (json['launch_time'] as num?)?.toDouble() ?? 0.0,
      travelTime: (json['travel_time'] as num?)?.toDouble() ?? 0.0,
      netTime: (json['net_time'] as num?)?.toDouble() ?? 0.0,
      floorTime: (json['floor_time'] as num?)?.toDouble() ?? 0.0,
      reachTime: (json['reach_time'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [target, direction, launchTime, travelTime, netTime, floorTime, reachTime];
}

class TennisPlayerModel extends Equatable {
  final int id;
  final String name;

  const TennisPlayerModel({
    required this.id,
    required this.name,
  });

  factory TennisPlayerModel.fromJson(Map<String, dynamic> json) {
    return TennisPlayerModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? 'Player',
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class TennisStateModel extends Equatable {
  final String state;
  final int timestamp;
  final TennisScoreModel score;
  final double travelTime;
  final TennisBallModel ball;
  final Map<int, int> playerPositions;
  final List<TennisPlayerModel> players;

  const TennisStateModel({
    required this.state,
    required this.timestamp,
    required this.score,
    required this.travelTime,
    required this.ball,
    required this.playerPositions,
    required this.players,
  });

  factory TennisStateModel.fromJson(Map<String, dynamic> json) {
    Map<int, int> _parsePositions(dynamic data) {
      if (data is Map) {
        return {
          0: data['0'] is int ? data['0'] : int.tryParse(data['0'].toString()) ?? 0,
          1: data['1'] is int ? data['1'] : int.tryParse(data['1'].toString()) ?? 0,
        };
      }
      return {0: 0, 1: 0};
    }

    return TennisStateModel(
      state: json['state'] as String? ?? 'WAITING',
      timestamp: json['timestamp'] as int? ?? 0,
      score: json['score'] != null 
          ? TennisScoreModel.fromJson(json['score']) 
          : const TennisScoreModel(
              points: {0: '0', 1: '0'},
              games: {0: 0, 1: 0},
              sets: {0: 0, 1: 0},
              serverIdx: 0,
              tiebreak: false,
              tiebreakPoints: {0: 0, 1: 0}
            ),
      travelTime: (json['travel_time'] as num?)?.toDouble() ?? 1.65,
      ball: json['ball'] != null 
          ? TennisBallModel.fromJson(json['ball'])
          : const TennisBallModel(
              target: 0, direction: 1, launchTime: 0.0, travelTime: 0.0, netTime: 0.0, floorTime: 0.0, reachTime: 0.0
            ),
      playerPositions: _parsePositions(json['player_positions']),
      players: (json['players'] as List<dynamic>? ?? [])
          .map((p) => TennisPlayerModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [state, timestamp, score, travelTime, ball, playerPositions, players];
}
