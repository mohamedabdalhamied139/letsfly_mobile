import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../core/audio/table_audio_service.dart';
import '../../core/constants/sound_cues.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/room_repository.dart';
import '../../data/repositories/room_ws_service.dart';
import '../../core/network/ws_client.dart';
import '../../core/audio/voice_chat_service.dart';
import '../../core/notifications/notification_policy.dart';
import '../../core/settings/settings_store.dart';

abstract class RoomState extends Equatable {
  const RoomState();
  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {}

class RoomLoading extends RoomState {
  final String message;
  const RoomLoading(this.message);
  @override
  List<Object?> get props => [message];
}

class RoomActive extends RoomState {
  final RoomModel room;
  final List<ChatMessageModel> chatMessages;
  final bool isWsConnected;

  const RoomActive({
    required this.room,
    this.chatMessages = const [],
    this.isWsConnected = false,
  });

  bool isCaptain(int myUserId) => room.isHost(myUserId);

  RoomActive copyWith({
    RoomModel? room,
    List<ChatMessageModel>? chatMessages,
    bool? isWsConnected,
  }) {
    return RoomActive(
      room: room ?? this.room,
      chatMessages: chatMessages ?? this.chatMessages,
      isWsConnected: isWsConnected ?? this.isWsConnected,
    );
  }

  @override
  List<Object?> get props => [room, chatMessages, isWsConnected];
}

class RoomLeft extends RoomState {}

class RoomError extends RoomState {
  final String message;
  const RoomError(this.message);
  @override
  List<Object?> get props => [message];
}

class RoomCubit extends Cubit<RoomState> {
  final RoomRepository _roomRepository;
  final RoomWsService _roomWsService;
  final AuthRepository _authRepository;
  final TableAudioService _audioService;
  final AccessibilityAnnouncer _announcer;
  final NotificationPolicy? _notificationPolicy;
  final SettingsStore? _settingsStore;
  late final VoiceChatService _voiceService;

  StreamSubscription? _snapshotSub;
  StreamSubscription? _chatSub;
  StreamSubscription? _rawEventSub;
  StreamSubscription? _wsStateSub;
  Timer? _gamePollTimer;
  bool _pollInFlight = false;

  RoomCubit({
    required RoomRepository roomRepository,
    required RoomWsService roomWsService,
    required AuthRepository authRepository,
    required TableAudioService audioService,
    AccessibilityAnnouncer? announcer,
    NotificationPolicy? notificationPolicy,
    SettingsStore? settingsStore,
  })  : _roomRepository = roomRepository,
        _roomWsService = roomWsService,
        _authRepository = authRepository,
        _audioService = audioService,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        _notificationPolicy = notificationPolicy,
        _settingsStore = settingsStore,
        super(RoomInitial()) {
    _voiceService = VoiceChatService(roomWs: _roomWsService);
  }

  Future<void> enterRoom(String roomId, {RoomModel? initialRoom}) async {
    emit(const RoomLoading('جاري الانضمام إلى الطاولة...'));
    _announcer.announce('جاري الانضمام إلى الطاولة...');

    try {
      final RoomModel room;
      if (initialRoom != null) {
        room = initialRoom;
      } else {
        room = await _roomRepository.joinRoom(roomId);
      }
      emit(RoomActive(
        room: room,
        isWsConnected: _roomWsService.state == WsConnectionState.connected,
      ));
      _announcer.announce('تم الانضمام إلى طاولة ${room.game}. المضيف: ${room.hostName}');
      await _audioService.playCue(SoundCues.playerJoined);

      // Bind all streams BEFORE connecting. The server sends room_snapshot
      // immediately after the socket opens, so subscribing afterwards loses it.
      _bindWebSocketSubscriptions();

      final token = await _authRepository.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await _roomWsService.connect(roomId, token);
        await _voiceService.attach(roomId);
        if (_settingsStore?.voiceAutoJoin == true) {
          await _voiceService.joinSession();
        }
      }

      if (room.isPlaying()) {
        _startPollingTimer();
        pollGameState();
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      emit(RoomError(err));
      _announcer.announce('فشل الانضمام: $err', priority: AnnouncePriority.assertive);
    }
  }

  void _bindWebSocketSubscriptions() {
    _wsStateSub?.cancel();
    _wsStateSub = _roomWsService.connectionStateStream.listen((wsState) async {
      if (wsState == WsConnectionState.reconnecting) {
        _voiceService.suspendForReconnect();
      } else if (wsState == WsConnectionState.connected) {
        await _voiceService.restoreAfterReconnect();
      }
      if (state is RoomActive) {
        final current = state as RoomActive;
        emit(current.copyWith(isWsConnected: wsState == WsConnectionState.connected));
      }
    });

    _snapshotSub?.cancel();
    _snapshotSub = _roomWsService.snapshotStream.listen((snapshot) {
      if (state is RoomActive) {
        final current = state as RoomActive;
        emit(current.copyWith(room: snapshot.room, isWsConnected: true));
      }
    });

    _chatSub?.cancel();
    _chatSub = _roomWsService.chatStream.listen((chat) {
      if (state is RoomActive) {
        final current = state as RoomActive;
        final updatedChat = List<ChatMessageModel>.from(current.chatMessages)..add(chat);
        emit(current.copyWith(chatMessages: updatedChat));
        if (_notificationPolicy != null) {
          _notificationPolicy!.handle(category: 'table_chat', text: 'رسالة من ${chat.sender}: ${chat.text}');
        } else {
          _announcer.announce('رسالة من ${chat.sender}: ${chat.text}');
        }
      }
    });

    _rawEventSub?.cancel();
    _rawEventSub = _roomWsService.rawEventStream.listen((event) async {
      final type = event['type'] as String? ?? '';
      if (type == 'player_joined') {
        final name = event['name'] as String? ?? 'لاعب';
        _announcer.announce('انضم $name إلى الطاولة');
        await _audioService.playCue(SoundCues.playerJoined);
      } else if (type == 'player_left') {
        final name = event['name'] as String? ?? 'لاعب';
        _announcer.announce('غادر $name الطاولة');
        await _audioService.playCue(SoundCues.playerLeft);
      } else if (type == 'bot_added') {
        final name = event['name'] as String? ?? 'بوت';
        _announcer.announce('تمت إضافة $name');
        await _audioService.playCue(SoundCues.playerJoined);
      } else if (type == 'bot_removed') {
        final name = event['name'] as String? ?? 'بوت';
        _announcer.announce('تمت إزالة $name');
        await _audioService.playCue(SoundCues.playerLeft);
      } else if (type == 'game_state_changed' ||
          type == 'game_started' ||
          type == 'uno_state_changed' ||
          type == 'domino_state_changed' ||
          type == 'american_domino_state_changed' ||
          type == 'farkle_state_changed' ||
          type == 'thief_state_changed' ||
          type == 'ninety_nine_state_changed' ||
          type == 'snakes_state_changed' ||
          type == 'scopa_state_changed') {
        if (type == 'game_started') {
          _announcer.announce('بدأت المباراة!');
          await _audioService.playCue(SoundCues.roundStart);
        }
        final statePayload = event['state'] as Map<String, dynamic>?;
        if (statePayload != null && state is RoomActive) {
          _roomWsService.dispatchGameState((state as RoomActive).room, statePayload);
        } else {
          pollGameState();
        }
      }
    });
  }

  void _startPollingTimer() {
    _stopPollingTimer();
    _gamePollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      pollGameState();
    });
  }

  void _stopPollingTimer() {
    _gamePollTimer?.cancel();
    _gamePollTimer = null;
    _pollInFlight = false;
  }

  Future<void> pollGameState() async {
    if (state is! RoomActive || _pollInFlight) return;
    final currentRoom = (state as RoomActive).room;
    if (!currentRoom.isPlaying()) return;
    _pollInFlight = true;
    try {
      final stateData = await _roomRepository.getGameState(currentRoom.roomId);
      if (state is RoomActive && (state as RoomActive).room.roomId == currentRoom.roomId) {
        _roomWsService.dispatchGameState(currentRoom, stateData);
      }
    } catch (_) {} finally {
      _pollInFlight = false;
    }
  }

  Future<void> addBot() async {
    if (state is! RoomActive) return;
    final roomId = (state as RoomActive).room.roomId;
    try {
      _announcer.announce('جاري إضافة بوت...');
      final updatedRoom = await _roomRepository.addBot(roomId);
      emit((state as RoomActive).copyWith(room: updatedRoom));
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _announcer.announce('فشل إضافة بوت: $err', priority: AnnouncePriority.assertive);
    }
  }

  Future<void> removeBot() async {
    if (state is! RoomActive) return;
    final roomId = (state as RoomActive).room.roomId;
    try {
      _announcer.announce('جاري إزالة البوت...');
      await _roomRepository.removeBot(roomId);
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _announcer.announce('فشل إزالة البوت: $err', priority: AnnouncePriority.assertive);
    }
  }

  Future<void> startGame({int? targetScore, Map<String, dynamic>? rules}) async {
    if (state is! RoomActive) return;
    final roomId = (state as RoomActive).room.roomId;
    try {
      _announcer.announce('جاري بدء المباراة...');
      final updatedRoom = await _roomRepository.startGame(
        roomId,
        targetScore: targetScore,
        rules: rules,
      );
      emit((state as RoomActive).copyWith(room: updatedRoom));
      _announcer.announce('بدأت المباراة بنجاح!');
      await _audioService.playCue(SoundCues.roundStart);
      _startPollingTimer();
      pollGameState();
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _announcer.announce('فشل بدء المباراة: $err', priority: AnnouncePriority.assertive);
    }
  }

  Future<void> stopGame() async {
    _stopPollingTimer();
    if (state is! RoomActive) return;
    final roomId = (state as RoomActive).room.roomId;
    try {
      final updatedRoom = await _roomRepository.stopGame(roomId);
      emit((state as RoomActive).copyWith(room: updatedRoom));
      _announcer.announce('تم إيقاف المباراة والعودة للانتظار.');
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _announcer.announce('فشل إيقاف المباراة: $err');
    }
  }

  Future<void> sendChat(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      await _roomWsService.sendChat(clean);
    } catch (_) {}
  }

  VoiceChatService get voiceService => _voiceService;

  Future<bool> toggleVoiceSession() => _voiceService.toggleSession();
  Future<bool> toggleVoiceMute() => _voiceService.toggleMute();

  Future<void> leaveRoom() async {
    _stopPollingTimer();
    if (state is RoomActive) {
      final roomId = (state as RoomActive).room.roomId;
      await _roomRepository.leaveRoom(roomId);
    }
    _snapshotSub?.cancel();
    _chatSub?.cancel();
    _rawEventSub?.cancel();
    _wsStateSub?.cancel();
    await _voiceService.detach();
    await _roomWsService.disconnect();
    emit(RoomLeft());
    _announcer.announce('تمت مغادرة الطاولة');
  }

  @override
  Future<void> close() {
    _stopPollingTimer();
    _snapshotSub?.cancel();
    _chatSub?.cancel();
    _rawEventSub?.cancel();
    _wsStateSub?.cancel();
    _voiceService.dispose();
    _roomWsService.disconnect();
    return super.close();
  }
}
