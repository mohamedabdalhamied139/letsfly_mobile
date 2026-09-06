import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/room_cubit.dart';
import '../bloc/auth_bloc.dart';
import '../screens/settings/game_settings_dialog.dart';
import '../../core/constants/app_colors.dart';

class TableWaitingView extends StatelessWidget {
  final String game;

  const TableWaitingView({super.key, required this.game});

  int _defaultTarget(String game) => const {
    'UNO': 500,
    'THIEF_HUNT': 1,
    'FARKLE': 1500,
    'DOMINO': 100,
    'AMERICAN_DOMINO': 150,
    'SNAKES_LADDERS': 100,
    'SCOPA': 11,
    'TENNIS': 1,
    'NINETY_NINE': 11,
  }[game.toUpperCase()] ?? 1;

  bool _canStart(String game, int count) {
    final limits = <String, List<int>>{
      'UNO': [2, 10],
      'THIEF_HUNT': [2, 10],
      'FARKLE': [2, 10],
      'DOMINO': [2, 5],
      'AMERICAN_DOMINO': [2, 5],
      'SNAKES_LADDERS': [2, 10],
      'SCOPA': [2, 6],
      'TENNIS': [2, 2],
      'NINETY_NINE': [2, 10],
    };
    final l = limits[game.toUpperCase()] ?? const [2, 10];
    return count >= l[0] && count <= l[1];
  }

  Future<void> _startWithSettings(BuildContext context, String game) async {
    final result = await showDialog<GameSettingsResult>(
      context: context,
      builder: (_) => GameSettingsDialog(
        game: game,
        defaultTarget: _defaultTarget(game),
      ),
    );
    if (!context.mounted || result == null) return;
    await context.read<RoomCubit>().startGame(
      targetScore: result.targetScore,
      rules: result.rules,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;

    if (roomState is! RoomActive) {
      return const Center(child: Text('في انتظار الاتصال بالطاولة...'));
    }

    final room = roomState.room;
    final isCaptain = room.isHost(currentUserId);
    final chatMessages = roomState.chatMessages;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                ...room.players.map((id) {
                  final name = room.playerNames[id] ?? (id < 0 ? 'بوت' : 'لاعب');
                  final score = room.scores[id] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    trailing: Text('$score', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
                if (room.players.isEmpty) const ListTile(title: Text('لاعبون')),
              ],
            ),
          ),
          if (chatMessages.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.builder(
                reverse: true,
                itemCount: chatMessages.length,
                itemBuilder: (_, i) {
                  final m = chatMessages[chatMessages.length - 1 - i];
                  return ListTile(dense: true, title: Text('${m.sender}: ${m.text}'));
                },
              ),
            ),
          if (room.isWaiting() && isCaptain && _canStart(room.game, room.players.length))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _startWithSettings(context, room.game),
                child: const Text('بدء اللعبة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
