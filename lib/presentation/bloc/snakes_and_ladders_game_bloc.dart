import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/snakes_and_ladders_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class SnakesAndLaddersGameEvent extends Equatable {
  const SnakesAndLaddersGameEvent();
  @override
  List<Object?> get props => [];
}

class SnakesAndLaddersStateUpdated extends SnakesAndLaddersGameEvent {
  final SnakesAndLaddersStateModel state;
  const SnakesAndLaddersStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class SnakesAndLaddersRollDice extends SnakesAndLaddersGameEvent {}
class SnakesAndLaddersScanRadar extends SnakesAndLaddersGameEvent {}

// --- States ---
abstract class SnakesAndLaddersGameState extends Equatable {
  const SnakesAndLaddersGameState();
  @override
  List<Object?> get props => [];
}

class SnakesAndLaddersGameWaiting extends SnakesAndLaddersGameState {}

class SnakesAndLaddersGamePlaying extends SnakesAndLaddersGameState {
  final SnakesAndLaddersStateModel game;
  final bool isMyTurn;

  const SnakesAndLaddersGamePlaying({
    required this.game,
    required this.isMyTurn,
  });

  SnakesAndLaddersGamePlaying copyWith({
    SnakesAndLaddersStateModel? game,
    bool? isMyTurn,
  }) {
    return SnakesAndLaddersGamePlaying(
      game: game ?? this.game,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }

  @override
  List<Object?> get props => [game, isMyTurn];
}

// --- Bloc ---
class SnakesAndLaddersGameBloc
    extends Bloc<SnakesAndLaddersGameEvent, SnakesAndLaddersGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;
  int _lastEventId = 0;
  int? _lastCurrentPlayerId;

  SnakesAndLaddersGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(SnakesAndLaddersGameWaiting()) {
    on<SnakesAndLaddersStateUpdated>(_onStateUpdated);
    on<SnakesAndLaddersRollDice>(_onRollDice);
    on<SnakesAndLaddersScanRadar>(_onScanRadar);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.snakesAndLaddersState != null) {
      add(SnakesAndLaddersStateUpdated(existingSnap!.snakesAndLaddersState!));
    } else if (existingSnap?.gameType == 'snakes_and_ladders' && existingSnap?.gameState != null) {
      try {
        final state = SnakesAndLaddersStateModel.fromJson(existingSnap!.gameState!);
        add(SnakesAndLaddersStateUpdated(state));
      } catch (_) {}
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.snakesAndLaddersState != null) {
        add(SnakesAndLaddersStateUpdated(snap.snakesAndLaddersState!));
      } else if (snap.gameType == 'snakes_and_ladders' && snap.gameState != null) {
        try {
          final state = SnakesAndLaddersStateModel.fromJson(snap.gameState!);
          add(SnakesAndLaddersStateUpdated(state));
        } catch (_) {}
      }
    });

    _rawEventSub?.cancel();
    _rawEventSub = _roomWsService.rawEventStream.listen((event) {
      final type = event['type'] as String? ?? '';
      if (type == 'game_action_result') {
        final ok = event['ok'] as bool? ?? false;
        if (!ok) {
          final err = event['error'] as String? ?? 'حركة غير صالحة';
          _announcer.announce(err, priority: AnnouncePriority.assertive);
          _audioService.playCue(SoundCues.invalidAction);
        }
      }
    });
  }

  Future<void> _onStateUpdated(
    SnakesAndLaddersStateUpdated event,
    Emitter<SnakesAndLaddersGameState> emit,
  ) async {
    final game = event.state;
    final isMyTurn = game.isMyTurn;

    if (!game.active && game.winnerId != null) {
      final isWinner = game.winnerId == _myUserId;
      if (isWinner) {
        await _audioService.playCue(SoundCues.matchWin);
        _announcer.announce('مبروك! لقد فزت بالمباراة!',
            priority: AnnouncePriority.assertive);
      } else {
        await _audioService.playCue(SoundCues.matchLoss);
        _announcer.announce('انتهت المباراة. الفائز: ${game.arrivalAction}',
            priority: AnnouncePriority.assertive);
      }
    }

    if (game.active && isMyTurn && _lastCurrentPlayerId != _myUserId) {
      await _audioService.playCue(SoundCues.turnStart);
      _announcer.announce('دورك الآن، يمكنك رمي النرد',
          priority: AnnouncePriority.assertive);
    } else if (game.active && !isMyTurn && _lastCurrentPlayerId != game.currentPlayerId) {
      _announcer.announce('دور ${game.currentPlayerName}');
    }

    _lastCurrentPlayerId = game.currentPlayerId;

    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      
      if (game.soundCues.isNotEmpty) {
        for (final cue in game.soundCues) {
          if (cue.isNotEmpty) {
            await _audioService.playCue(cue);
          }
        }
      } else {
        await _audioService.playEvent(
          gameType: 'SNAKES_LADDERS',
          eventType: game.eventType,
          serverCue: game.soundCue.isNotEmpty ? game.soundCue : null,
        );
      }

      if (game.lastAction.isNotEmpty && !isMyTurn) {
        _announcer.announce(game.lastAction);
      } else if (game.lastAction.isNotEmpty && isMyTurn) {
        _announcer.announce(game.lastAction, priority: AnnouncePriority.assertive);
      }
    }

    emit(SnakesAndLaddersGamePlaying(
      game: game,
      isMyTurn: isMyTurn,
    ));
  }

  Future<void> _onRollDice(
      SnakesAndLaddersRollDice event, Emitter<SnakesAndLaddersGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('roll');
    } catch (_) {}
  }

  Future<void> _onScanRadar(
      SnakesAndLaddersScanRadar event, Emitter<SnakesAndLaddersGameState> emit) async {
    if (state is! SnakesAndLaddersGamePlaying) return;
    final cur = state as SnakesAndLaddersGamePlaying;
    final radar = cur.game.radar;
    if (radar == null) {
      _announcer.announce('الرادار غير متاح حاليا');
      return;
    }
    
    String msg = 'أنت في المربع ${radar.position}. باقي لك ${radar.distanceToFinish} خطوة للنهاية.';
    if (radar.nearestLadder != null) {
      msg += ' أقرب سلم أمامك يبدأ من المربع ${radar.nearestLadder!.start} ويصعد إلى ${radar.nearestLadder!.end} بعد ${radar.nearestLadder!.distance} خطوات.';
    }
    if (radar.nearestSnake != null) {
      msg += ' أقرب ثعبان أمامك رأسه عند المربع ${radar.nearestSnake!.start} وينزل إلى ${radar.nearestSnake!.end} بعد ${radar.nearestSnake!.distance} خطوات.';
    }
    _announcer.announce(msg, priority: AnnouncePriority.assertive);
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
