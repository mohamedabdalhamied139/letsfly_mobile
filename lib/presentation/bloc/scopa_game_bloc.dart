import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/scopa_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class ScopaGameEvent extends Equatable {
  const ScopaGameEvent();
  @override
  List<Object?> get props => [];
}

class ScopaStateUpdated extends ScopaGameEvent {
  final ScopaGameStateModel state;
  const ScopaStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class ScopaSelectCard extends ScopaGameEvent {
  final int index;
  const ScopaSelectCard(this.index);
  @override
  List<Object?> get props => [index];
}

class ScopaNextCard extends ScopaGameEvent {}
class ScopaPreviousCard extends ScopaGameEvent {}

class ScopaPlaySelectedCard extends ScopaGameEvent {}

class ScopaPlayCardExplicit extends ScopaGameEvent {
  final int index;
  const ScopaPlayCardExplicit(this.index);
  @override List<Object?> get props => [index];
}

// --- States ---
abstract class ScopaGameState extends Equatable {
  const ScopaGameState();
  @override
  List<Object?> get props => [];
}

class ScopaGameWaiting extends ScopaGameState {}

class ScopaGamePlaying extends ScopaGameState {
  final ScopaGameStateModel game;
  final int selectedIndex;
  final bool isMyTurn;

  const ScopaGamePlaying({
    required this.game,
    this.selectedIndex = 0,
    required this.isMyTurn,
  });

  ScopaCardModel? get selectedCard {
    if (game.myHand.isEmpty || selectedIndex < 0 || selectedIndex >= game.myHand.length) {
      return null;
    }
    return game.myHand[selectedIndex];
  }

  ScopaGamePlaying copyWith({
    ScopaGameStateModel? game,
    int? selectedIndex,
    bool? isMyTurn,
  }) {
    return ScopaGamePlaying(
      game: game ?? this.game,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }

  @override
  List<Object?> get props => [game, selectedIndex, isMyTurn];
}

// --- Bloc ---
class ScopaGameBloc extends Bloc<ScopaGameEvent, ScopaGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;
  int _lastEventId = 0;
  int? _lastCurrentTurnId;

  ScopaGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(ScopaGameWaiting()) {
    on<ScopaStateUpdated>(_onStateUpdated);
    on<ScopaSelectCard>(_onSelectCard);
    on<ScopaNextCard>(_onNextCard);
    on<ScopaPreviousCard>(_onPreviousCard);
    on<ScopaPlaySelectedCard>(_onPlaySelectedCard);
    on<ScopaPlayCardExplicit>(_onPlayCardExplicit);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.scopaState != null) {
      add(ScopaStateUpdated(existingSnap!.scopaState!));
    } else if (existingSnap?.rawJson['game_type'] == 'SCOPA') {
      try {
        final state = ScopaGameStateModel.fromJson(existingSnap!.rawJson['game_state']);
        add(ScopaStateUpdated(state));
      } catch (_) {}
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.scopaState != null) {
        add(ScopaStateUpdated(snap.scopaState!));
      } else if (snap.rawJson['game_type'] == 'SCOPA') {
        final state = ScopaGameStateModel.fromJson(snap.rawJson['game_state']);
        add(ScopaStateUpdated(state));
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
    ScopaStateUpdated event,
    Emitter<ScopaGameState> emit,
  ) async {
    final game = event.state;
    final isMyTurn = game.isMyTurn(_myUserId);

    if (!game.active && (game.winnerId != null || game.roundSummary.contains('نهاية المباراة'))) {
      final isWinner = game.winnerId == _myUserId || (game.isTeamGame && game.roundSummary.contains('الفائز: فريق ${game.teams[_myUserId.toString()]}'));
      if (isWinner) {
        await _audioService.playCue(SoundCues.matchWin);
        _announcer.announce('مبروك! لقد فزت بالمباراة!', priority: AnnouncePriority.assertive);
      } else {
        await _audioService.playCue(SoundCues.matchLoss);
        _announcer.announce('انتهت المباراة. الفائز: ${game.roundSummary}', priority: AnnouncePriority.assertive);
      }
    } else if (!game.active && game.roundSummary.isNotEmpty && game.eventId > _lastEventId) {
       _announcer.announce(game.roundSummary, priority: AnnouncePriority.assertive);
    }

    // Audio & Turn announcement
    if (game.active && isMyTurn && _lastCurrentTurnId != _myUserId) {
      await _audioService.playCue(SoundCues.turnStart);
      _announcer.announce('دورك الآن للعب!', priority: AnnouncePriority.assertive);
    } else if (game.active && !isMyTurn && _lastCurrentTurnId != game.currentTurnId && game.currentTurnId != null) {
      _announcer.announce('دور ${game.currentTurnName}');
    }

    _lastCurrentTurnId = game.currentTurnId;

    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      await _audioService.playEvent(
        gameType: 'SCOPA',
        eventType: game.eventType,
        serverCue: game.soundCue,
      );
      if (game.lastAction.isNotEmpty && (!isMyTurn || game.eventType == 'SCOPA_SWEEP')) {
        _announcer.announce(game.lastAction);
      }
    }

    if (state is ScopaGamePlaying) {
      final cur = state as ScopaGamePlaying;
      final safeIndex = cur.selectedIndex.clamp(0, (game.myHand.length - 1).clamp(0, 999));
      emit(cur.copyWith(
        game: game,
        selectedIndex: safeIndex,
        isMyTurn: isMyTurn,
      ));
    } else {
      emit(ScopaGamePlaying(
        game: game,
        selectedIndex: 0,
        isMyTurn: isMyTurn,
      ));
    }
  }

  void _onSelectCard(ScopaSelectCard event, Emitter<ScopaGameState> emit) {
    if (state is! ScopaGamePlaying) return;
    final cur = state as ScopaGamePlaying;
    final maxIdx = cur.game.myHand.length - 1;
    if (maxIdx < 0) return;
    final safeIdx = event.index.clamp(0, maxIdx);
    emit(cur.copyWith(selectedIndex: safeIdx));
    final card = cur.game.myHand[safeIdx];
    _announcer.announce(card.arabicName);
  }

  void _onNextCard(ScopaNextCard event, Emitter<ScopaGameState> emit) {
    if (state is! ScopaGamePlaying) return;
    final cur = state as ScopaGamePlaying;
    final count = cur.game.myHand.length;
    if (count <= 1) return;
    final nextIdx = (cur.selectedIndex + 1) % count;
    add(ScopaSelectCard(nextIdx));
  }

  void _onPreviousCard(ScopaPreviousCard event, Emitter<ScopaGameState> emit) {
    if (state is! ScopaGamePlaying) return;
    final cur = state as ScopaGamePlaying;
    final count = cur.game.myHand.length;
    if (count <= 1) return;
    final prevIdx = (cur.selectedIndex - 1 + count) % count;
    add(ScopaSelectCard(prevIdx));
  }

  Future<void> _onPlayCardExplicit(ScopaPlayCardExplicit event, Emitter<ScopaGameState> emit) async {
    if (state is! ScopaGamePlaying) return;
    final cur = state as ScopaGamePlaying;
    if (!cur.isMyTurn) { _announcer.announce('ليس دورك للعب'); return; }
    if (event.index < 0 || event.index >= cur.game.myHand.length) return;
    try {
      await _roomWsService.sendGameAction('play', cardId: '${event.index}');
    } catch (_) { _announcer.announce('تعذر إرسال الحركة'); }
  }

  Future<void> _onPlaySelectedCard(ScopaPlaySelectedCard event, Emitter<ScopaGameState> emit) async {
    if (state is! ScopaGamePlaying) return;
    final cur = state as ScopaGamePlaying;
    if (cur.game.myHand.isEmpty) return;
    add(ScopaPlayCardExplicit(cur.selectedIndex));
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
