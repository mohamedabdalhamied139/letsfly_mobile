import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/thief_hunt_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class ThiefHuntGameEvent extends Equatable {
  const ThiefHuntGameEvent();
  @override
  List<Object?> get props => [];
}

class ThiefHuntStateUpdated extends ThiefHuntGameEvent {
  final ThiefHuntStateModel state;
  const ThiefHuntStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class ThiefHuntChooseFloor extends ThiefHuntGameEvent {
  final int floor;
  const ThiefHuntChooseFloor(this.floor);
  @override
  List<Object?> get props => [floor];
}

class ThiefHuntBeginAnswering extends ThiefHuntGameEvent {}

class ThiefHuntSubmitAnswer extends ThiefHuntGameEvent {
  final int floor;
  const ThiefHuntSubmitAnswer(this.floor);
  @override
  List<Object?> get props => [floor];
}

// --- States ---
abstract class ThiefHuntGameState extends Equatable {
  const ThiefHuntGameState();
  @override
  List<Object?> get props => [];
}

class ThiefHuntGameWaiting extends ThiefHuntGameState {}

class ThiefHuntGamePlaying extends ThiefHuntGameState {
  final ThiefHuntStateModel game;
  final bool isMyTurn;

  const ThiefHuntGamePlaying({
    required this.game,
    required this.isMyTurn,
  });

  ThiefHuntGamePlaying copyWith({
    ThiefHuntStateModel? game,
    bool? isMyTurn,
  }) {
    return ThiefHuntGamePlaying(
      game: game ?? this.game,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }

  @override
  List<Object?> get props => [game, isMyTurn];
}

// --- Bloc ---
class ThiefHuntGameBloc extends Bloc<ThiefHuntGameEvent, ThiefHuntGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final int _myUserId;
  final AccessibilityAnnouncer _announcer;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;

  int _lastEventId = 0;
  bool _matchResultSoundPlayed = false;

  ThiefHuntGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(ThiefHuntGameWaiting()) {
    on<ThiefHuntStateUpdated>(_onStateUpdated);
    on<ThiefHuntChooseFloor>(_onChooseFloor);
    on<ThiefHuntBeginAnswering>(_onBeginAnswering);
    on<ThiefHuntSubmitAnswer>(_onSubmitAnswer);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.thiefHuntState != null) {
      add(ThiefHuntStateUpdated(existingSnap!.thiefHuntState!));
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.thiefHuntState != null) {
        add(ThiefHuntStateUpdated(snap.thiefHuntState!));
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
    ThiefHuntStateUpdated event,
    Emitter<ThiefHuntGameState> emit,
  ) async {
    final game = event.state;
    final isMyTurn = game.isThief ? (game.phase == 'choose_floor') : (game.phase == 'answering');

    // Trigger sound cues based on event ID
    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      
      if (game.lastAction.isNotEmpty) {
        _announcer.announce(game.lastAction);
      }

      await _audioService.playEvent(
        gameType: 'THIEF_HUNT',
        eventType: game.eventType,
        serverCue: game.soundCue,
      );

      final et = game.eventType;
      if (et == 'ESCAPE_START') {
        String narration = '';
        if (game.startFloor != null) {
          narration += 'اللص في الطابق ${game.startFloor}';
        }
        if (game.directions.isNotEmpty) {
          if (narration.isNotEmpty) narration += '، ';
          narration += game.directions.join('، ');
        }
        if (narration.isNotEmpty) {
          _announcer.announce(narration, priority: AnnouncePriority.assertive);
        }
      } else if (et == 'ROUND_WIN') {
        await _audioService.playCue('THIEF_CAUGHT');
        await _audioService.playCue('THIEF_ROUND_END');
      } else if (et == 'MATCH_WIN') {
        if (!_matchResultSoundPlayed) {
          _matchResultSoundPlayed = true;
          if (game.matchWinnerId == _myUserId) {
            await _audioService.playCue(SoundCues.matchWin);
          } else {
            await _audioService.playCue(SoundCues.matchLoss);
          }
        }
      }
    }

    if (state is ThiefHuntGamePlaying) {
      final cur = state as ThiefHuntGamePlaying;
      emit(cur.copyWith(
        game: game,
        isMyTurn: isMyTurn,
      ));
    } else {
      emit(ThiefHuntGamePlaying(
        game: game,
        isMyTurn: isMyTurn,
      ));
    }
  }

  Future<void> _onChooseFloor(
    ThiefHuntChooseFloor event,
    Emitter<ThiefHuntGameState> emit,
  ) async {
    await _roomWsService.sendGameAction(
      'choose_floor',
      cardId: '${event.floor}',
    );
  }

  Future<void> _onBeginAnswering(
    ThiefHuntBeginAnswering event,
    Emitter<ThiefHuntGameState> emit,
  ) async {
    await _roomWsService.sendGameAction('begin_answering');
  }

  Future<void> _onSubmitAnswer(
    ThiefHuntSubmitAnswer event,
    Emitter<ThiefHuntGameState> emit,
  ) async {
    await _roomWsService.sendGameAction(
      'answer',
      cardId: '${event.floor}',
    );
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
