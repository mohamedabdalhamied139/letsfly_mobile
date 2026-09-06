import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/domino_state_model.dart';
import '../../data/repositories/room_ws_service.dart';

// --- Events ---
abstract class DominoGameEvent extends Equatable {
  const DominoGameEvent();
  @override
  List<Object?> get props => [];
}

class DominoStateUpdated extends DominoGameEvent {
  final DominoGameStateModel state;
  const DominoStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class DominoSelectTile extends DominoGameEvent {
  final int index;
  const DominoSelectTile(this.index);
  @override
  List<Object?> get props => [index];
}

class DominoNextTile extends DominoGameEvent {}
class DominoPreviousTile extends DominoGameEvent {}

class DominoPlayTileExplicit extends DominoGameEvent {
  final int index;
  final String? side;
  const DominoPlayTileExplicit(this.index, {this.side});
  @override List<Object?> get props => [index, side];
}

class DominoPlaySelectedTile extends DominoGameEvent {
  final String side; // "auto", "left", "right"
  const DominoPlaySelectedTile({this.side = 'auto'});
  @override
  List<Object?> get props => [side];
}

class DominoDrawTile extends DominoGameEvent {}
class DominoPassTurn extends DominoGameEvent {}

// --- States ---
abstract class DominoGameState extends Equatable {
  const DominoGameState();
  @override
  List<Object?> get props => [];
}

class DominoGameWaiting extends DominoGameState {}

class DominoGamePlaying extends DominoGameState {
  final DominoGameStateModel game;
  final int selectedIndex;
  final bool isMyTurn;

  const DominoGamePlaying({
    required this.game,
    this.selectedIndex = 0,
    required this.isMyTurn,
  });

  DominoHandTile? get selectedTile {
    if (game.hand.isEmpty || selectedIndex < 0 || selectedIndex >= game.hand.length) {
      return null;
    }
    return game.hand[selectedIndex];
  }

  DominoGamePlaying copyWith({
    DominoGameStateModel? game,
    int? selectedIndex,
    bool? isMyTurn,
  }) {
    return DominoGamePlaying(
      game: game ?? this.game,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }

  @override
  List<Object?> get props => [game, selectedIndex, isMyTurn];
}

// --- Bloc ---
class DominoGameBloc extends Bloc<DominoGameEvent, DominoGameState> {
  final RoomWsService _roomWsService;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final int _myUserId;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _rawEventSub;
  int _lastEventId = 0;
  int? _lastCurrentPlayerId;

  DominoGameBloc({
    required RoomWsService roomWsService,
    required TableAudioService audioService,
    required int myUserId,
    AccessibilityAnnouncer? announcer,
  })  : _roomWsService = roomWsService,
        _audioService = audioService,
        _myUserId = myUserId,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        super(DominoGameWaiting()) {
    on<DominoStateUpdated>(_onStateUpdated);
    on<DominoSelectTile>(_onSelectTile);
    on<DominoNextTile>(_onNextTile);
    on<DominoPreviousTile>(_onPreviousTile);
    on<DominoPlaySelectedTile>(_onPlaySelectedTile);
    on<DominoPlayTileExplicit>(_onPlayTileExplicit);
    on<DominoDrawTile>(_onDrawTile);
    on<DominoPassTurn>(_onPassTurn);

    _listenToRoomSocket();
  }

  void _listenToRoomSocket() {
    final existingSnap = _roomWsService.lastSnapshot;
    if (existingSnap?.dominoState != null) {
      add(DominoStateUpdated(existingSnap!.dominoState!));
    }

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snap) {
      if (snap.dominoState != null) {
        add(DominoStateUpdated(snap.dominoState!));
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
    DominoStateUpdated event,
    Emitter<DominoGameState> emit,
  ) async {
    final game = event.state;
    final isMyTurn = game.currentPlayerId == _myUserId;

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
      final leftInfo = game.leftEnd != null ? 'اليسار: ${game.leftEnd}' : 'الطاولة فارغة';
      final rightInfo = game.rightEnd != null ? '، اليمين: ${game.rightEnd}' : '';
      _announcer.announce('دورك الآن! $leftInfo$rightInfo', priority: AnnouncePriority.assertive);
    } else if (game.active && !isMyTurn && _lastCurrentPlayerId != game.currentPlayerId) {
      _announcer.announce('دور ${game.currentPlayerName}');
    }

    _lastCurrentPlayerId = game.currentPlayerId;

    // Trigger sound cue from server if new
    if (game.eventId > _lastEventId) {
      _lastEventId = game.eventId;
      final isAmerican = game.scoringMode != null || game.openEndsSum != null;
      await _audioService.playEvent(
        gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO',
        eventType: game.eventType,
        serverCue: game.soundCue,
      );
      if (game.lastAction.isNotEmpty && !isMyTurn) {
        _announcer.announce(game.lastAction);
      }
    }

    if (state is DominoGamePlaying) {
      final cur = state as DominoGamePlaying;
      final safeIndex = cur.selectedIndex.clamp(0, (game.hand.length - 1).clamp(0, 999));
      emit(cur.copyWith(
        game: game,
        selectedIndex: safeIndex,
        isMyTurn: isMyTurn,
      ));
    } else {
      emit(DominoGamePlaying(
        game: game,
        selectedIndex: 0,
        isMyTurn: isMyTurn,
      ));
    }
  }

  void _onSelectTile(DominoSelectTile event, Emitter<DominoGameState> emit) {
    if (state is! DominoGamePlaying) return;
    final cur = state as DominoGamePlaying;
    final maxIdx = cur.game.hand.length - 1;
    if (maxIdx < 0) return;
    final safeIdx = event.index.clamp(0, maxIdx);
    emit(cur.copyWith(selectedIndex: safeIdx));
    final tile = cur.game.hand[safeIdx];
    
    String label = tile.label;
    if (!tile.isValid) {
      label += " (غير صالحة)";
    } else if (tile.validSides.length == 1) {
      final sideAr = tile.validSides[0] == 'left' ? 'اليسار' : 'اليمين';
      label += " (صالحة لـ $sideAr)";
    } else if (tile.validSides.length == 2) {
      label += " (صالحة للجهتين)";
    }
    _announcer.announce(label);
  }

  void _onNextTile(DominoNextTile event, Emitter<DominoGameState> emit) {
    if (state is! DominoGamePlaying) return;
    final cur = state as DominoGamePlaying;
    final count = cur.game.hand.length;
    if (count <= 1) return;
    final nextIdx = (cur.selectedIndex + 1) % count;
    add(DominoSelectTile(nextIdx));
  }

  void _onPreviousTile(DominoPreviousTile event, Emitter<DominoGameState> emit) {
    if (state is! DominoGamePlaying) return;
    final cur = state as DominoGamePlaying;
    final count = cur.game.hand.length;
    if (count <= 1) return;
    final prevIdx = (cur.selectedIndex - 1 + count) % count;
    add(DominoSelectTile(prevIdx));
  }

  Future<void> _onPlayTileExplicit(DominoPlayTileExplicit event, Emitter<DominoGameState> emit) async {
    if (state is! DominoGamePlaying) return;
    final cur = state as DominoGamePlaying;
    if (!cur.isMyTurn) { _announcer.announce('ليس دورك للعب'); return; }
    if (event.index < 0 || event.index >= cur.game.hand.length) return;
    final tile = cur.game.hand[event.index];
    if (!tile.isValid) { _announcer.announce('هذه القطعة غير صالحة للعب'); return; }
    if (tile.validSides.length > 1 && (event.side == null || event.side!.isEmpty)) {
      _announcer.announce('اختر جهة وضع القطعة');
      return;
    }
    try {
      await _roomWsService.sendGameAction('play', cardId: '${tile.index}', side: event.side ?? tile.validSides.first);
    } catch (_) { _announcer.announce('تعذر إرسال الحركة'); }
  }

  Future<void> _onPlaySelectedTile(DominoPlaySelectedTile event, Emitter<DominoGameState> emit) async {
    if (state is! DominoGamePlaying) return;
    final cur = state as DominoGamePlaying;
    final tile = cur.selectedTile;
    if (tile == null) return;
    
    if (!tile.isValid) {
      _announcer.announce('هذه القطعة غير صالحة للعب');
      return;
    }
    
    try {
      await _roomWsService.sendGameAction(
        'play',
        cardId: '${tile.index}',
        side: event.side,
      );
    } catch (_) {}
  }

  Future<void> _onDrawTile(DominoDrawTile event, Emitter<DominoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('draw');
    } catch (_) {}
  }

  Future<void> _onPassTurn(DominoPassTurn event, Emitter<DominoGameState> emit) async {
    try {
      await _roomWsService.sendGameAction('pass');
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _snapshotSub?.cancel();
    _rawEventSub?.cancel();
    return super.close();
  }
}
