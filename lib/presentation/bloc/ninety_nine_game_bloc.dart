import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/ninety_nine_card_model.dart';
import '../../data/models/ninety_nine_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class NinetyNineGameEvent extends Equatable {
  const NinetyNineGameEvent();
  @override
  List<Object?> get props => [];
}

class NinetyNineStateUpdated extends NinetyNineGameEvent {
  final NinetyNineGameStateModel state;
  const NinetyNineStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class NinetyNineSelectCard extends NinetyNineGameEvent {
  final int index;
  const NinetyNineSelectCard(this.index);
  @override
  List<Object?> get props => [index];
}

class NinetyNineNextCard extends NinetyNineGameEvent {}
class NinetyNinePreviousCard extends NinetyNineGameEvent {}

class NinetyNinePlaySelectedCard extends NinetyNineGameEvent {}

class NinetyNinePlayCardExplicit extends NinetyNineGameEvent {
  final int index;
  const NinetyNinePlayCardExplicit(this.index);
  @override List<Object?> get props => [index];
}

class NinetyNineMakeChoice extends NinetyNineGameEvent {
  final int choiceValue;
  const NinetyNineMakeChoice(this.choiceValue);
  @override
  List<Object?> get props => [choiceValue];
}

class NinetyNineCancelChoice extends NinetyNineGameEvent {}

// --- States ---
abstract class NinetyNineGameState extends Equatable {
  const NinetyNineGameState();
  @override
  List<Object?> get props => [];
}

class NinetyNineGameWaiting extends NinetyNineGameState {}

class NinetyNineGamePlaying extends NinetyNineGameState {
  final NinetyNineGameStateModel game;
  final int selectedIndex;
  final bool isMyTurn;

  const NinetyNineGamePlaying({
    required this.game,
    this.selectedIndex = 0,
    required this.isMyTurn,
  });

  NinetyNineCardModel? get selectedCard {
    if (game.hand.isEmpty || selectedIndex < 0 || selectedIndex >= game.hand.length) {
      return null;
    }
    return game.hand[selectedIndex];
  }

  NinetyNineGamePlaying copyWith({
    NinetyNineGameStateModel? game,
    int? selectedIndex,
    bool? isMyTurn,
  }) {
    return NinetyNineGamePlaying(
      game: game ?? this.game,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }

  @override
  List<Object?> get props => [game, selectedIndex, isMyTurn];
}

// --- Bloc ---
class NinetyNineGameBloc extends Bloc<NinetyNineGameEvent, NinetyNineGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;
  int _lastEventId = 0;
  int? _lastCurrentPlayerId;

  NinetyNineGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(NinetyNineGameWaiting()) {
    on<NinetyNineStateUpdated>(_onStateUpdated);
    on<NinetyNineSelectCard>(_onSelectCard);
    on<NinetyNineNextCard>(_onNextCard);
    on<NinetyNinePreviousCard>(_onPreviousCard);
    on<NinetyNinePlaySelectedCard>(_onPlaySelectedCard);
    on<NinetyNinePlayCardExplicit>(_onPlayCardExplicit);
    on<NinetyNineMakeChoice>(_onMakeChoice);
    on<NinetyNineCancelChoice>(_onCancelChoice);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.ninetyNineState != null) {
      try {
        final stateModel = NinetyNineGameStateModel.fromJson(existingSnap!.ninetyNineState as Map<String, dynamic>);
        add(NinetyNineStateUpdated(stateModel));
      } catch (_) {}
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.ninetyNineState != null) {
        try {
          final stateModel = NinetyNineGameStateModel.fromJson(snap.ninetyNineState as Map<String, dynamic>);
          add(NinetyNineStateUpdated(stateModel));
        } catch (e) {
          print('Error parsing NinetyNine state: $e');
        }
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
    NinetyNineStateUpdated event,
    Emitter<NinetyNineGameState> emit,
  ) async {
    final game = event.state;
    final isMyTurn = game.isMyTurn(_myUserId);

    if (!game.active && game.winnerId != null) {
      final isWinner = game.winnerId == _myUserId;
      if (isWinner) {
        await _audioService.playCue(SoundCues.matchWin);
        _announcer.announce('مبروك! لقد فزت بالمباراة!', priority: AnnouncePriority.assertive);
      } else {
        await _audioService.playCue(SoundCues.matchLoss);
        _announcer.announce('انتهت المباراة. ${game.lastAction}', priority: AnnouncePriority.assertive);
      }
    }

    // Audio & Turn announcement
    if (game.active && isMyTurn && _lastCurrentPlayerId != _myUserId) {
      await _audioService.playCue(SoundCues.turnStart);
      _announcer.announce('دورك الآن للعب! المجموع في الساحة: ${game.pileValue}', priority: AnnouncePriority.assertive);
    } else if (game.active && !isMyTurn && _lastCurrentPlayerId != game.currentPlayerId) {
      _announcer.announce('دور ${game.currentPlayerName}');
    }

    _lastCurrentPlayerId = game.currentPlayerId;

    // Trigger sound cue from server if new
    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      await _audioService.playEvent(
        gameType: 'NINETY_NINE',
        eventType: game.eventType,
        serverCue: game.soundCue,
      );
      if (game.lastAction.isNotEmpty && !isMyTurn) {
        _announcer.announce(game.lastAction);
      }
    }

    if (state is NinetyNineGamePlaying) {
      final cur = state as NinetyNineGamePlaying;
      final safeIndex = cur.selectedIndex.clamp(0, (game.hand.length - 1).clamp(0, 999));
      emit(cur.copyWith(
        game: game,
        selectedIndex: safeIndex,
        isMyTurn: isMyTurn,
      ));
    } else {
      emit(NinetyNineGamePlaying(
        game: game,
        selectedIndex: 0,
        isMyTurn: isMyTurn,
      ));
    }
  }

  void _onSelectCard(NinetyNineSelectCard event, Emitter<NinetyNineGameState> emit) {
    if (state is! NinetyNineGamePlaying) return;
    final cur = state as NinetyNineGamePlaying;
    final maxIdx = cur.game.hand.length - 1;
    if (maxIdx < 0) return;
    final safeIdx = event.index.clamp(0, maxIdx);
    emit(cur.copyWith(selectedIndex: safeIdx));
    final card = cur.game.hand[safeIdx];
    _announcer.announce(card.getLocalizedLabel('ar'));
  }

  void _onNextCard(NinetyNineNextCard event, Emitter<NinetyNineGameState> emit) {
    if (state is! NinetyNineGamePlaying) return;
    final cur = state as NinetyNineGamePlaying;
    final count = cur.game.hand.length;
    if (count <= 1) return;
    final nextIdx = (cur.selectedIndex + 1) % count;
    add(NinetyNineSelectCard(nextIdx));
  }

  void _onPreviousCard(NinetyNinePreviousCard event, Emitter<NinetyNineGameState> emit) {
    if (state is! NinetyNineGamePlaying) return;
    final cur = state as NinetyNineGamePlaying;
    final count = cur.game.hand.length;
    if (count <= 1) return;
    final prevIdx = (cur.selectedIndex - 1 + count) % count;
    add(NinetyNineSelectCard(prevIdx));
  }

  Future<void> _onPlaySelectedCard(NinetyNinePlaySelectedCard event, Emitter<NinetyNineGameState> emit) async {
    if (state is! NinetyNineGamePlaying) return;
    final cur = state as NinetyNineGamePlaying;
    final card = cur.selectedCard;
    if (card == null) return;
    final index = cur.game.hand.indexWhere((c) => c.cardId == card.cardId);
    if (index >= 0) add(NinetyNinePlayCardExplicit(index));
  }

  Future<void> _onPlayCardExplicit(NinetyNinePlayCardExplicit event, Emitter<NinetyNineGameState> emit) async {
    if (state is! NinetyNineGamePlaying) return;
    final cur = state as NinetyNineGamePlaying;
    if (!cur.isMyTurn) { _announcer.announce('ليس دورك للعب'); return; }
    if (event.index < 0 || event.index >= cur.game.hand.length) return;
    final card = cur.game.hand[event.index];
    try {
      await _roomWsService.sendGameAction('play', cardId: card.cardId);
    } catch (_) { _announcer.announce('تعذر إرسال الحركة'); }
  }

  Future<void> _onMakeChoice(NinetyNineMakeChoice event, Emitter<NinetyNineGameState> emit) async {
    try {
      await _roomWsService.sendGameAction(
        'choose',
        cardId: event.choiceValue.toString(),
      );
    } catch (_) {}
  }

  Future<void> _onCancelChoice(NinetyNineCancelChoice event, Emitter<NinetyNineGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('cancel_choice');
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
