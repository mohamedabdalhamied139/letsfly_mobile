import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/lobby_ws_service.dart';
import '../../data/repositories/room_repository.dart';
import '../../core/network/ws_client.dart';
import '../../data/repositories/activity_repository.dart';

abstract class LobbyState extends Equatable {
  const LobbyState();
  @override
  List<Object?> get props => [];
}

class LobbyInitial extends LobbyState {}

class LobbyLoading extends LobbyState {}

class LobbyLoaded extends LobbyState {
  final List<RoomModel> rooms;
  final bool isWsConnected;

  const LobbyLoaded({required this.rooms, this.isWsConnected = false});

  @override
  List<Object?> get props => [rooms, isWsConnected];
}

class LobbyError extends LobbyState {
  final String message;
  const LobbyError(this.message);
  @override
  List<Object?> get props => [message];
}

class LobbyCubit extends Cubit<LobbyState> {
  final RoomRepository _roomRepository;
  final LobbyWsService _lobbyWsService;
  final AuthRepository _authRepository;
  final AccessibilityAnnouncer _announcer;
  final ActivityRepository? _activityRepository;

  StreamSubscription? _wsEventSub;
  StreamSubscription? _wsStateSub;
  bool _wsInitialized = false;

  LobbyCubit({
    required RoomRepository roomRepository,
    required LobbyWsService lobbyWsService,
    required AuthRepository authRepository,
    AccessibilityAnnouncer? announcer,
    ActivityRepository? activityRepository,
  })  : _roomRepository = roomRepository,
        _lobbyWsService = lobbyWsService,
        _authRepository = authRepository,
        _announcer = announcer ?? StandardAccessibilityAnnouncer(),
        _activityRepository = activityRepository,
        super(LobbyInitial());

  Future<void> loadRooms() async {
    emit(LobbyLoading());
    try {
      final rooms = await _roomRepository.getRooms();
      emit(LobbyLoaded(rooms: rooms));
      _announcer.announce('تم تحميل الطاولات المتاحة. عدد الطاولات: ${rooms.length}');
      await _initWebSocket();
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      emit(LobbyError(err));
      _announcer.announce('تعذر تحميل الطاولات: $err');
    }
  }

  Future<void> _initWebSocket() async {
    try {
      final token = await _authRepository.getAccessToken();
      if (token != null && token.isNotEmpty) {
        // Subscribe before connect so immediate lobby events are not lost.
        _wsEventSub?.cancel();
        _wsEventSub = _lobbyWsService.lobbyEventStream.listen((event) {
          final type = event['type'] as String? ?? '';
          if (type == 'activity_event') { _activityRepository?.publishLiveEvent(event); return; }
          if (type == 'room_created' || type == 'room_updated' || type == 'room_deleted') {
            _refreshRoomsSilently();
          }
        });

        _wsStateSub?.cancel();
        _wsStateSub = _lobbyWsService.connectionStateStream.listen((wsState) {
          if (state is LobbyLoaded) {
            final current = state as LobbyLoaded;
            emit(LobbyLoaded(
              rooms: current.rooms,
              isWsConnected: wsState == WsConnectionState.connected,
            ));
          }
        });

        if (!_wsInitialized) {
          await _lobbyWsService.connect(token);
          _wsInitialized = true;
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshRoomsSilently() async {
    try {
      final rooms = await _roomRepository.getRooms();
      if (state is LobbyLoaded) {
        emit(LobbyLoaded(rooms: rooms, isWsConnected: true));
      }
    } catch (_) {}
  }

  Future<RoomModel?> createRoom({String game = 'UNO'}) async {
    try {
      _announcer.announce('جاري إنشاء طاولة $game...');
      final newRoom = await _roomRepository.createRoom(game: game);
      _announcer.announce('تم إنشاء طاولة $game بنجاح!');
      await loadRooms();
      return newRoom;
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      _announcer.announce('فشل إنشاء الطاولة: $err', priority: AnnouncePriority.assertive);
      return null;
    }
  }

  @override
  Future<void> close() {
    _wsEventSub?.cancel();
    _wsStateSub?.cancel();
    _lobbyWsService.disconnect();
    return super.close();
  }
}
