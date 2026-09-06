import 'package:equatable/equatable.dart';

/// Transport-neutral view of any server-authoritative game state.
/// The mobile client intentionally keeps game rules on the shared Windows/server
/// engine and only renders state + submits protocol actions.
class GameStateModel extends Equatable {
  final String game;
  final Map<String, dynamic> data;

  const GameStateModel({required this.game, required this.data});

  bool get active => data['active'] == true;
  bool get isMyTurn => data['is_my_turn'] == true;
  String get lastAction => '${data['last_action'] ?? ''}';
  String get eventType => '${data['event_type'] ?? ''}';
  String get soundCue => '${data['sound_cue'] ?? ''}';

  List<Map<String, dynamic>> get players {
    final raw = data['players'];
    final scores = data['scores'];
    final scoreMap = scores is Map ? scores : const {};
    if (raw is List) {
      return raw.whereType<Map>().map((e) {
        final p = Map<String, dynamic>.from(e);
        if (p['score'] == null && p['points'] == null) {
          final id = p['user_id'] ?? p['player_id'] ?? p['id'];
          p['score'] = scoreMap[id] ?? scoreMap['$id'] ?? 0;
        }
        return p;
      }).toList();
    }
    if (scoreMap.isNotEmpty) {
      return scoreMap.entries.map((e) => <String, dynamic>{'player_id': e.key, 'name': 'لاعب ${e.key}', 'score': e.value}).toList();
    }
    return const [];
  }

  List<dynamic> get hand => (data['hand'] is List) ? data['hand'] as List : const [];
  List<dynamic> get myHand => (data['my_hand'] is List) ? data['my_hand'] as List : const [];
  List<dynamic> get dice => (data['dice'] is List) ? data['dice'] as List : const [];

  @override
  List<Object?> get props => [game, data];
}
