import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/audio/tennis_sound_engine.dart';
import '../../data/models/tennis_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class TennisGameEvent extends Equatable {
  const TennisGameEvent();
  @override
  List<Object?> get props => [];
}

class TennisStateUpdated extends TennisGameEvent {
  final TennisStateModel state;
  const TennisStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class TennisMoveLane extends TennisGameEvent {
  final int lane;
  const TennisMoveLane(this.lane);
  @override
  List<Object?> get props => [lane];
}

class TennisServe extends TennisGameEvent {
  final int lane;
  const TennisServe(this.lane);
  @override
  List<Object?> get props => [lane];
}

// --- States ---
abstract class TennisGameState extends Equatable {
  const TennisGameState();
  @override
  List<Object?> get props => [];
}

class TennisGameWaiting extends TennisGameState {}

class TennisGamePlaying extends TennisGameState {
  final TennisStateModel game;
  final int myLane;
  final bool isMyServe;

  const TennisGamePlaying({
    required this.game,
    this.myLane = 0,
    this.isMyServe = false,
  });

  TennisGamePlaying copyWith({
    TennisStateModel? game,
    int? myLane,
    bool? isMyServe,
  }) {
    return TennisGamePlaying(
      game: game ?? this.game,
      myLane: myLane ?? this.myLane,
      isMyServe: isMyServe ?? this.isMyServe,
    );
  }

  @override
  List<Object?> get props => [game, myLane, isMyServe];
}

// --- Bloc ---
class TennisGameBloc extends Bloc<TennisGameEvent, TennisGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final TennisSoundEngine _tennisSoundEngine;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;
  int _localIdx = 0;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;

  TennisGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    TennisSoundEngine? tennisSoundEngine,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _tennisSoundEngine = tennisSoundEngine ?? TennisSoundEngine(),
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(TennisGameWaiting()) {
    on<TennisStateUpdated>(_onStateUpdated);
    on<TennisMoveLane>(_onMoveLane);
    on<TennisServe>(_onServe);

    _listenToRoomSocket();
  }

  TennisSoundEngine get tennisSoundEngine => _tennisSoundEngine;
  TableAudioService get audioService => _audioService;

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.tennisState != null) {
      try {
        add(TennisStateUpdated(TennisStateModel.fromJson(existingSnap!.tennisState!)));
      } catch (_) {}
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.tennisState != null) {
        add(TennisStateUpdated(TennisStateModel.fromJson(snap.tennisState!)));
      }
    });

    _rawEventSub?.cancel();
    _rawEventSub = _roomWsService.rawEventStream.listen((event) {
      final type = event['type'] as String? ?? '';
      
      if (type == 'tennis_sound') {
        _handleTimedSound(event);
      } else if (type == 'tennis_action_result') {
        final res = event['result'] is Map
            ? Map<String, dynamic>.from(event['result'] as Map)
            : event;
        _handleActionResult(res);
      }
    });
  }

  void _handleTimedSound(Map<String, dynamic> event) {
    final sound = event['sound'] as String? ?? '';
    final lane = (event['lane'] as num?)?.toInt() ?? 0;
    final direction = (event['direction'] as num?)?.toInt() ?? 1;

    final audioLane = _localIdx == 1 ? -lane : lane;

    if (sound == 'floor_hit') {
      final isIncoming = (direction == 1 && _localIdx == 0) || (direction == -1 && _localIdx == 1);
      final vol = isIncoming ? 1.0 : 0.30;
      _tennisSoundEngine.playFloorHit(audioLane, vol);
    } else if (sound == 'net_pass') {
      _tennisSoundEngine.playNetPass(audioLane);
    }
  }

  void _startIncomingBall(Map<String, dynamic> res) {
    final ball = res['ball'] is Map ? res['ball'] as Map : null;
    final sender = (res['sender'] as num?)?.toInt() ?? 1;
    if (sender == 1) {
      final target = (ball?['target'] as num?)?.toInt() ?? 0;
      final audioTarget = _localIdx == 1 ? -target : target;
      _tennisSoundEngine.playOpponentHit(audioTarget);
    }
  }

  void _handleActionResult(Map<String, dynamic> res) {
    final hitType = res['hit_type'] as String? ?? '';
    final playerIdx = (res['player_idx'] as num?)?.toInt() ?? 0;

    // === Serve / initial trajectory ===
    if (hitType.isEmpty && res.containsKey('sender')) {
      _startIncomingBall(res);
      return;
    }

    // === PLAYER HIT (bounce "racket") ===
    if (hitType == 'racket') {
      if (playerIdx == _localIdx) {
        final curLane = state is TennisGamePlaying ? (state as TennisGamePlaying).myLane : 0;
        _tennisSoundEngine.playRacketHit(curLane);
      } else {
        final ball = res['ball'] is Map ? res['ball'] as Map : null;
        final oppTarget = (ball?['target'] as num?)?.toInt() ?? 0;
        final audioTarget = _localIdx == 1 ? -oppTarget : oppTarget;
        _tennisSoundEngine.playOpponentHit(audioTarget);
      }
      return;
    }

    // === WALL BOUNCE (opponent_racket_hit) ===
    if (hitType == 'wall') {
      _startIncomingBall(res);
      return;
    }

    // === MISS / POINT SCORED (boundary) ===
    if (hitType == 'boundary') {
      final scoreResult = res['score_result'] is Map ? res['score_result'] as Map : null;
      final sc = scoreResult?['score'] is Map ? scoreResult!['score'] as Map : null;
      final events = (scoreResult?['events'] is List)
          ? (scoreResult!['events'] as List).map((e) => e.toString()).toList()
          : <String>[];

      final pts = sc?['points'] is Map ? sc!['points'] as Map : null;
      final serverIdx = (sc?['server_idx'] as num?)?.toInt() ?? 0;

      final isMyScore = playerIdx != _localIdx;

      final p0Score = pts != null ? '${pts[0] ?? pts['0'] ?? '0'}' : '0';
      final p1Score = pts != null ? '${pts[1] ?? pts['1'] ?? '0'}' : '0';

      final isTiebreak = (sc?['tiebreak'] == true) || events.contains('tiebreak_point');
      final tbPts = sc?['tiebreak_points'] is Map ? sc!['tiebreak_points'] as Map : null;

      if (events.contains('match_won')) {
        _tennisSoundEngine.playCrowd(variant: 2, volume: 1.0);
        _tennisSoundEngine.playMatchWon();
        _announcer.announce('نهاية المباراة!');
      } else if (events.contains('set_won')) {
        _tennisSoundEngine.playCrowd(variant: 2, volume: 1.0);
        _tennisSoundEngine.playSetWon();
      } else if (events.contains('game_won')) {
        _tennisSoundEngine.playCrowd(variant: 2, volume: 1.0);
        _tennisSoundEngine.playGameWon();
      } else if (isMyScore) {
        _tennisSoundEngine.playWin();
        _tennisSoundEngine.playScoreAnnouncement(
          p0Score,
          p1Score,
          serverIdx: serverIdx,
          isTiebreak: isTiebreak,
          tiebreakPoints: tbPts,
        );
      } else {
        _tennisSoundEngine.playMiss();
        _tennisSoundEngine.playScoreAnnouncement(
          p0Score,
          p1Score,
          serverIdx: serverIdx,
          isTiebreak: isTiebreak,
          tiebreakPoints: tbPts,
        );
      }
      return;
    }

    if (res.containsKey('sender')) {
      _startIncomingBall(res);
    }
  }

  Future<void> _onStateUpdated(TennisStateUpdated event, Emitter<TennisGameState> emit) async {
    final game = event.state;
    final myPlayerIndex = game.players.indexWhere((p) => p.id == _myUserId);
    _localIdx = myPlayerIndex >= 0 ? myPlayerIndex : 0; // Default to 0
    final isMyServe = game.score.serverIdx == _localIdx && game.timestamp == 1; // 1 = WAITING_KEY
    
    if (game.timestamp == 16) { // GAME_OVER
      _announcer.announce('انتهت المباراة!');
    } else if (isMyServe && state is! TennisGamePlaying) {
      _announcer.announce('المباراة بدأت، اضغط مرتين للعب الإرسال');
    }

    if (state is TennisGamePlaying) {
      final cur = state as TennisGamePlaying;
      // We don't overwrite myLane from server to avoid jitter, client is authoritative for input
      emit(cur.copyWith(
        game: game,
        isMyServe: isMyServe,
      ));
    } else {
      emit(TennisGamePlaying(
        game: game,
        myLane: game.playerPositions[_localIdx] ?? 0,
        isMyServe: isMyServe,
      ));
    }
  }

  Future<void> _onMoveLane(TennisMoveLane event, Emitter<TennisGameState> emit) async {
    if (state is! TennisGamePlaying) return;
    final cur = state as TennisGamePlaying;
    
    final newLane = event.lane.clamp(-1, 1);
    if (newLane == cur.myLane) return; // No change

    emit(cur.copyWith(myLane: newLane));
    
    // Play move spatial sound (jm_left, jm_center, jm_right)
    _tennisSoundEngine.playMove(newLane);

    // Suppress verbose screen reader speech during active rally so spatial audio cues are clear.
    // Only speak lane if waiting to serve.
    if (cur.isMyServe) {
      String direction = newLane == -1 ? 'يسار' : (newLane == 1 ? 'يمين' : 'وسط');
      _announcer.announce('تحركت $direction');
    }
    
    try {
      await _roomWsService.sendGameAction('position', data: {'lane': newLane});
    } catch (_) {}
  }

  Future<void> _onServe(TennisServe event, Emitter<TennisGameState> emit) async {
    if (state is! TennisGamePlaying) return;
    final cur = state as TennisGamePlaying;
    
    if (!cur.isMyServe) {
      _announcer.announce('ليس دورك في الإرسال');
      return;
    }

    try {
      await _roomWsService.sendGameAction('serve', data: {'lane': cur.myLane});
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    _tennisSoundEngine.dispose();
    return super.close();
  }
}
