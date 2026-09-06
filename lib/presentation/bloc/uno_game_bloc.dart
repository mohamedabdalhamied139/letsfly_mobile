import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/uno_card_model.dart';
import '../../data/models/uno_game_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class UnoGameEvent extends Equatable {
  const UnoGameEvent();
  @override
  List<Object?> get props => [];
}

class UnoStateUpdated extends UnoGameEvent {
  final UnoGameStateModel state;
  const UnoStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class UnoSelectCard extends UnoGameEvent {
  final int index;
  const UnoSelectCard(this.index);
  @override
  List<Object?> get props => [index];
}

class UnoNextCard extends UnoGameEvent {}
class UnoPreviousCard extends UnoGameEvent {}
class UnoToggleGrouping extends UnoGameEvent {}

class UnoPlaySelectedCard extends UnoGameEvent {
  final String? chosenColor;
  const UnoPlaySelectedCard({this.chosenColor});
  @override
  List<Object?> get props => [chosenColor];
}

class UnoPlayCardExplicit extends UnoGameEvent {
  final String cardId;
  final String? chosenColor;
  const UnoPlayCardExplicit(this.cardId, {this.chosenColor});
  @override
  List<Object?> get props => [cardId, chosenColor];
}

class UnoDrawCard extends UnoGameEvent {}
class UnoPassTurn extends UnoGameEvent {}
class UnoCallUno extends UnoGameEvent {}
class UnoCatchUno extends UnoGameEvent {
  final int? targetPlayerId;
  const UnoCatchUno({this.targetPlayerId});
  @override
  List<Object?> get props => [targetPlayerId];
}
class UnoChallengeBluff extends UnoGameEvent {}
class UnoSlapBuzzer extends UnoGameEvent {}

// --- States ---
abstract class UnoGameState extends Equatable {
  const UnoGameState();
  @override
  List<Object?> get props => [];
}

class UnoGameWaiting extends UnoGameState {}

class UnoGamePlaying extends UnoGameState {
  final UnoGameStateModel game;
  final int selectedIndex;
  final bool groupByColor;
  final bool isMyTurn;
  final UnoCardModel? wildPendingCard;

  const UnoGamePlaying({
    required this.game,
    this.selectedIndex = 0,
    this.groupByColor = true,
    required this.isMyTurn,
    this.wildPendingCard,
  });

  UnoCardModel? get selectedCard {
    final sorted = sortedHand;
    if (sorted.isEmpty || selectedIndex < 0 || selectedIndex >= sorted.length) {
      return null;
    }
    return sorted[selectedIndex];
  }

  List<UnoCardModel> get sortedHand {
    final list = List<UnoCardModel>.from(game.hand);
    if (groupByColor) {
      list.sort((a, b) {
        final cmp = a.color.compareTo(b.color);
        if (cmp != 0) return cmp;
        return (a.value ?? 0).compareTo(b.value ?? 0);
      });
    } else {
      list.sort((a, b) {
        final cmp = (a.value ?? 0).compareTo(b.value ?? 0);
        if (cmp != 0) return cmp;
        return a.color.compareTo(b.color);
      });
    }
    return list;
  }

  UnoGamePlaying copyWith({
    UnoGameStateModel? game,
    int? selectedIndex,
    bool? groupByColor,
    bool? isMyTurn,
    UnoCardModel? wildPendingCard,
    bool clearWildPending = false,
  }) {
    return UnoGamePlaying(
      game: game ?? this.game,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      groupByColor: groupByColor ?? this.groupByColor,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      wildPendingCard: clearWildPending ? null : (wildPendingCard ?? this.wildPendingCard),
    );
  }

  @override
  List<Object?> get props => [game, selectedIndex, groupByColor, isMyTurn, wildPendingCard];
}

// --- Bloc ---
class UnoGameBloc extends Bloc<UnoGameEvent, UnoGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;
  int _lastEventId = 0;
  int? _lastCurrentPlayerId;

  UnoGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(UnoGameWaiting()) {
    on<UnoStateUpdated>(_onStateUpdated);
    on<UnoSelectCard>(_onSelectCard);
    on<UnoNextCard>(_onNextCard);
    on<UnoPreviousCard>(_onPreviousCard);
    on<UnoToggleGrouping>(_onToggleGrouping);
    on<UnoPlaySelectedCard>(_onPlaySelectedCard);
    on<UnoPlayCardExplicit>(_onPlayCardExplicit);
    on<UnoDrawCard>(_onDrawCard);
    on<UnoPassTurn>(_onPassTurn);
    on<UnoCallUno>(_onCallUno);
    on<UnoCatchUno>(_onCatchUno);
    on<UnoChallengeBluff>(_onChallengeBluff);
    on<UnoSlapBuzzer>(_onSlapBuzzer);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.unoState != null) {
      add(UnoStateUpdated(existingSnap!.unoState!));
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.unoState != null) {
        add(UnoStateUpdated(snap.unoState!));
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
    UnoStateUpdated event,
    Emitter<UnoGameState> emit,
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
        _announcer.announce('انتهت المباراة. الفائز: ${game.lastAction}', priority: AnnouncePriority.assertive);
      }
    }

    // Audio & Turn announcement
    if (game.active && isMyTurn && _lastCurrentPlayerId != _myUserId) {
      await _audioService.playCue(SoundCues.turnStart);
      final topLabel = game.topCard?.getLocalizedLabel('ar') ?? '';
      _announcer.announce('دورك الآن للعب! الكارت في الساحة: $topLabel، اللون الحالي: ${game.currentColor}', priority: AnnouncePriority.assertive);
    } else if (game.active && !isMyTurn && _lastCurrentPlayerId != game.currentPlayerId) {
      _announcer.announce('دور ${game.currentPlayerName}');
    }

    _lastCurrentPlayerId = game.currentPlayerId;

    // Trigger sound cue from server if new
    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      await _audioService.playEvent(
        gameType: 'UNO',
        eventType: game.eventType,
        serverCue: game.soundCue,
      );
      if (game.lastAction.isNotEmpty && !isMyTurn) {
        _announcer.announce(game.lastAction);
      }
    }

    if (state is UnoGamePlaying) {
      final cur = state as UnoGamePlaying;
      final safeIndex = cur.selectedIndex.clamp(0, (game.hand.length - 1).clamp(0, 999));
      emit(cur.copyWith(
        game: game,
        selectedIndex: safeIndex,
        isMyTurn: isMyTurn,
      ));
    } else {
      emit(UnoGamePlaying(
        game: game,
        selectedIndex: 0,
        groupByColor: true,
        isMyTurn: isMyTurn,
      ));
    }
  }

  void _onSelectCard(UnoSelectCard event, Emitter<UnoGameState> emit) {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    final maxIdx = cur.sortedHand.length - 1;
    if (maxIdx < 0) return;
    final safeIdx = event.index.clamp(0, maxIdx);
    emit(cur.copyWith(selectedIndex: safeIdx));
    final card = cur.sortedHand[safeIdx];
    _announcer.announce(card.getLocalizedLabel('ar'));
  }

  void _onNextCard(UnoNextCard event, Emitter<UnoGameState> emit) {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    final count = cur.sortedHand.length;
    if (count <= 1) return;
    final nextIdx = (cur.selectedIndex + 1) % count;
    add(UnoSelectCard(nextIdx));
  }

  void _onPreviousCard(UnoPreviousCard event, Emitter<UnoGameState> emit) {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    final count = cur.sortedHand.length;
    if (count <= 1) return;
    final prevIdx = (cur.selectedIndex - 1 + count) % count;
    add(UnoSelectCard(prevIdx));
  }

  void _onToggleGrouping(UnoToggleGrouping event, Emitter<UnoGameState> emit) {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    final newGroup = !cur.groupByColor;
    emit(cur.copyWith(groupByColor: newGroup, selectedIndex: 0));
    _announcer.announce(newGroup ? 'تم تجميع الكروت حسب اللون' : 'تم تجميع الكروت حسب القيمة');
  }

  Future<void> _onPlaySelectedCard(UnoPlaySelectedCard event, Emitter<UnoGameState> emit) async {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    final card = cur.selectedCard;
    if (card == null) return;
    final index = cur.game.hand.indexWhere((c) => c.cardId == card.cardId);
    if (index >= 0) add(UnoPlayCardExplicit(card.cardId, chosenColor: event.chosenColor));
  }

  Future<void> _onPlayCardExplicit(UnoPlayCardExplicit event, Emitter<UnoGameState> emit) async {
    if (state is! UnoGamePlaying) return;
    final cur = state as UnoGamePlaying;
    if (!cur.isMyTurn) {
      _announcer.announce('ليس دورك للعب');
      return;
    }
    final hand = cur.game.hand;
    final cardIndex = hand.indexWhere((c) => c.cardId == event.cardId);
    if (cardIndex < 0) return;
    final card = hand[cardIndex];
    if (!card.isPlayable(cur.game.topCard, cur.game.currentColor)) {
      _announcer.announce('لا يمكنك لعب هذا الكارت الآن');
      return;
    }
    if (card.isWild && (event.chosenColor == null || event.chosenColor!.isEmpty)) {
      emit(cur.copyWith(wildPendingCard: card));
      _announcer.announce('اختر لون الكارت الحر');
      return;
    }
    emit(cur.copyWith(wildPendingCard: null, clearWildPending: true));
    try {
      await _roomWsService.sendGameAction('play', cardId: card.cardId, chosenColor: event.chosenColor);
    } catch (e) {
      _announcer.announce('تعذر إرسال الحركة');
    }
  }

  Future<void> _onDrawCard(UnoDrawCard event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('draw');
      await _audioService.playCue(SoundCues.cardDraw);
      _announcer.announce('سحبت كارتًا من السحابة');
    } catch (_) {}
  }

  Future<void> _onPassTurn(UnoPassTurn event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('pass');
      _announcer.announce('مررت دورك');
    } catch (_) {}
  }

  Future<void> _onCallUno(UnoCallUno event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('call_uno');
      await _audioService.playCue(SoundCues.unoCalled);
      _announcer.announce('أونو!');
    } catch (_) {}
  }

  Future<void> _onCatchUno(UnoCatchUno event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('catch_uno', targetPlayerId: event.targetPlayerId?.toString());
      await _audioService.playCue(SoundCues.unoPenalty);
      _announcer.announce('كشف أونو!');
    } catch (_) {}
  }

  Future<void> _onChallengeBluff(UnoChallengeBluff event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('challenge_bluff');
      await _audioService.playCue(SoundCues.bluffChallenge);
      _announcer.announce('تحدي الخداع!');
    } catch (_) {}
  }

  Future<void> _onSlapBuzzer(UnoSlapBuzzer event, Emitter<UnoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('buzzer');
      _announcer.announce('ضغطت الجرس!');
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
