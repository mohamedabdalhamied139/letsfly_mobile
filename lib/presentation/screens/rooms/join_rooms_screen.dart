import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/room_model.dart';
import '../../bloc/lobby_cubit.dart';
import '../../bloc/room_cubit.dart';
import 'room_lobby_screen.dart';

class JoinRoomsScreen extends StatefulWidget {
  const JoinRoomsScreen({super.key});

  @override
  State<JoinRoomsScreen> createState() => _JoinRoomsScreenState();
}

class _JoinRoomsScreenState extends State<JoinRoomsScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LobbyCubit>().loadRooms();
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  void _enterRoom(String roomId) {
    context.read<RoomCubit>().enterRoom(roomId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
    );
  }

  void _showJoinByIdDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('انضمام برقم الطاولة'),
        content: TextField(
          controller: _roomIdController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'اكتب رقم الطاولة (Room ID)',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final id = val.trim();
            if (id.isNotEmpty) {
              Navigator.pop(ctx);
              _enterRoom(id);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final id = _roomIdController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(ctx);
                _enterRoom(id);
              }
            },
            child: const Text('دخول الطاولة'),
          ),
        ],
      ),
    );
  }

  String _formatRoomText(RoomModel room) {
    final game = _getGameArabicLabel(room.game);
    final host = room.hostName.isNotEmpty ? room.hostName : 'مجهول';
    final count = room.players.length;
    final status = room.isPlaying() ? 'قيد اللعب' : 'في الانتظار';
    return '$game — $host — $count/10 لاعبين — $status';
  }

  String _getGameArabicLabel(String gameCode) {
    switch (gameCode.toUpperCase()) {
      case 'UNO':
        return 'أونو';
      case 'SCOPA':
        return 'سكوبا';
      case 'NINETY_NINE':
        return 'تسعة وتسعون';
      case 'FARKLE':
        return 'فاركل';
      case 'SNAKES_LADDERS':
        return 'السلم والثعبان';
      case 'DOMINO':
        return 'الدومينو';
      case 'AMERICAN_DOMINO':
        return 'الدومينو الأمريكية';
      case 'THIEF_HUNT':
        return 'صيد اللصوص';
      case 'TENNIS':
        return 'التنس';
      default:
        return gameCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطاولات المتاحة حاليًا'),
        actions: [
          Semantics(
            label: 'انضمام برقم الطاولة',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.dialpad),
              tooltip: 'انضمام برقم الطاولة',
              onPressed: _showJoinByIdDialog,
            ),
          ),
          Semantics(
            label: 'تحديث قائمة الطاولات',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الطاولات',
              onPressed: () => context.read<LobbyCubit>().loadRooms(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<LobbyCubit, LobbyState>(
          builder: (context, state) {
            if (state is LobbyLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('جاري فحص الطاولات المتاحة...'),
                  ],
                ),
              );
            }

            if (state is LobbyLoaded) {
              if (state.rooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد طاولات متاحة حاليًا.',
                        style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.dialpad),
                        label: const Text('انضمام برقم الطاولة المباشر'),
                        onPressed: _showJoinByIdDialog,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: state.rooms.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, index) {
                  final room = state.rooms[index];
                  final desc = _formatRoomText(room);

                  return Semantics(
                    button: true,
                    label: desc,
                    hint: 'اضغط مرتين للانضمام إلى هذه الطاولة',
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: room.isPlaying() ? AppColors.unoGreen : AppColors.primary,
                        child: Icon(
                          room.isPlaying() ? Icons.play_arrow : Icons.hourglass_empty,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        desc,
                        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                      ),
                      trailing: const Icon(Icons.login, color: AppColors.accent),
                      onTap: () => _enterRoom(room.roomId),
                    ),
                  );
                },
              );
            }

            if (state is LobbyError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'تعذر تحميل الطاولات:\n${state.message}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<LobbyCubit>().loadRooms(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
