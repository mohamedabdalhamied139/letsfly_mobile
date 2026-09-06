import 'dart:async';

import 'package:equatable/equatable.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:letsfly_mobile/data/models/farkle_state_model.dart';

import 'package:letsfly_mobile/data/repositories/room_ws_service.dart';

import 'package:letsfly_mobile/core/audio/table_audio_service.dart';

import 'package:letsfly_mobile/core/accessibility/accessibility_announcer.dart';

import 'package:letsfly_mobile/core/constants/sound_cues.dart';



abstract class FarkleGameEvent extends Equatable {

  const FarkleGameEvent();

  @override

  List<Object?> get props => [];

}



class FarkleStateUpdated extends FarkleGameEvent {

  final FarkleStateModel state;

  const FarkleStateUpdated(this.state);

  @override

  List<Object?> get props => [state];

}



class FarkleActionRoll extends FarkleGameEvent {}

class FarkleActionBank extends FarkleGameEvent {}



class FarkleActionScore extends FarkleGameEvent {

  final List<int> indices;

  const FarkleActionScore(this.indices);

  @override

  List<Object?> get props => [indices];

}



abstract class FarkleGameState extends Equatable {

  const FarkleGameState();

  @override

  List<Object?> get props => [];

}



class FarkleGameWaiting extends FarkleGameState {}



class FarkleGamePlaying extends FarkleGameState {

  final FarkleStateModel game;

  final bool isMyTurn;



  const FarkleGamePlaying({

    required this.game,

    required this.isMyTurn,

  });



  @override

  List<Object?> get props => [game, isMyTurn];

}



class FarkleGameBloc extends Bloc<FarkleGameEvent, FarkleGameState> {

  final RoomWsService _roomWsService;

  final TableAudioService _audioService;

  final AccessibilityAnnouncer _announcer;

  final int _myUserId;



  StreamSubscription? _snapshotSub;

  StreamSubscription? _rawEventSub;

  int _lastEventId = 0;

  int? _lastCurrentPlayerId;



  FarkleGameBloc({

    required RoomWsService roomWsService,

    required TableAudioService audioService,

    required int myUserId,

    AccessibilityAnnouncer? announcer,

  })  : _roomWsService = roomWsService,

        _audioService = audioService,

        _myUserId = myUserId,

        _announcer = announcer ?? StandardAccessibilityAnnouncer(),

        super(FarkleGameWaiting()) {

    on<FarkleStateUpdated>(_onStateUpdated);

    on<FarkleActionRoll>(_onRoll);

    on<FarkleActionBank>(_onBank);

    on<FarkleActionScore>(_onScore);



    _listenToRoomSocket();

  }



  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.farkleState != null) {
      add(FarkleStateUpdated(existingSnap!.farkleState!));
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.farkleState != null) {
        add(FarkleStateUpdated(snap.farkleState!));
      }
    });



    _rawEventSub?.cancel();

    _rawEventSub = _roomWsService.rawEventStream.listen((event) {

      final type = event['type'] as String? ?? '';

      if (type == 'game_action_result') {

        final ok = event['ok'] as bool? ?? false;

        if (!ok) {

          final err = event['error'] as String? ?? 'حدث خطأ';

          _announcer.announce(err, priority: AnnouncePriority.assertive);

          _audioService.playCue(SoundCues.invalidAction);

        }

      } else if (type == 'farkle_match_finished') {

        final winnerName = event['winner_name'] as String? ?? 'لاعب';

        _announcer.announce('انتهت اللعبة! الفائز هو $winnerName');

      }

    });

  }



  Future<void> _onStateUpdated(FarkleStateUpdated event, Emitter<FarkleGameState> emit) async {
    final state = event.state;
    if (!state.active) {
      if (state.winnerId != null && state.eventId > _lastEventId) {
        _lastEventId = state.eventId;
        final isWinner = state.winnerId == _myUserId;
        await _audioService.playCue(isWinner ? SoundCues.matchWin : SoundCues.matchLoss);
        _announcer.announce(
          isWinner ? 'مبروك! لقد فزت بالمباراة!' : 'انتهت المباراة. الفائز: ${state.currentPlayerName}',
          priority: AnnouncePriority.assertive,
        );
      }
      emit(FarkleGameWaiting());
      return;
    }

    final isMyTurn = state.currentPlayerId == _myUserId;

    if (state.eventId > _lastEventId) {
      _lastEventId = state.eventId;
      await _audioService.playEvent(
        gameType: 'FARKLE',
        eventType: state.eventType,
        serverCue: state.soundCue,
      );
      if (state.lastAction.isNotEmpty) {
        _announcer.announce(state.lastAction);
      }
      if (isMyTurn && state.currentPlayerId != _lastCurrentPlayerId) {
        await _audioService.playCue(SoundCues.turnStart);
        _announcer.announce('دورك!', priority: AnnouncePriority.assertive);
      }
    }

    _lastCurrentPlayerId = state.currentPlayerId;

    emit(FarkleGamePlaying(
      game: state,
      isMyTurn: isMyTurn,
    ));
  }

  Future<void> _onRoll(FarkleActionRoll event, Emitter<FarkleGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('roll');
    } catch (_) {}
  }



  Future<void> _onBank(FarkleActionBank event, Emitter<FarkleGameState> emit) async {

    try {

      await _roomWsService.sendGameAction('bank');

    } catch (_) {}

  }



  Future<void> _onScore(FarkleActionScore event, Emitter<FarkleGameState> emit) async {

    try {

      final indicesStr = event.indices.join(',');

      await _roomWsService.sendGameAction('score', data: {'value': indicesStr});

    } catch (_) {}

  }



  @override

  Future<void> close() {

    _snapshotSub?.cancel();

    _rawEventSub?.cancel();

    return super.close();

  }

}

