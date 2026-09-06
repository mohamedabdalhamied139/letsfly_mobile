import 'package:flutter/material.dart';
import '../screens/settings/game_settings_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/room_cubit.dart';
import '../../core/constants/app_colors.dart';

/// Table-only actions (game controls, bots, voice chat, leave table)
enum TableOptionAction {
  start,
  stop,
  addBot,
  removeBot,
  leaveTable,
}

typedef TableMenuAction = TableOptionAction;
extension TableMenuActionCompat on TableOptionAction {
  static TableOptionAction get leave => TableOptionAction.leaveTable;
}

Future<TableOptionAction?> showTableOptionsMenu(
  BuildContext context, {
  required bool isCaptain,
  required bool playing,
}) async {
  return showModalBottomSheet<TableOptionAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerRight,
                child: const Text(
                  'خيارات الطاولة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(),

              // Game Table actions
              ListTile(
                enabled: isCaptain,
                leading: Icon(
                  playing ? Icons.stop : Icons.play_arrow,
                  color: isCaptain ? AppColors.unoGreen : Colors.grey,
                ),
                title: Text(playing ? 'إيقاف اللعبة' : 'بدء اللعبة'),
                onTap: isCaptain
                    ? () => Navigator.of(sheetCtx).pop(
                          playing ? TableOptionAction.stop : TableOptionAction.start,
                        )
                    : null,
              ),
              if (isCaptain && !playing) ...[
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('إضافة بوت'),
                  onTap: () => Navigator.of(sheetCtx).pop(TableOptionAction.addBot),
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('إزالة بوت'),
                  onTap: () => Navigator.of(sheetCtx).pop(TableOptionAction.removeBot),
                ),
              ],

              const Divider(),

              // Table Exit
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppColors.error),
                title: const Text('مغادرة الطاولة'),
                onTap: () => Navigator.of(sheetCtx).pop(TableOptionAction.leaveTable),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> executeTableOptionAction(
  BuildContext context,
  TableOptionAction action, {
  required bool isCaptain,
  required bool playing,
  required String game,
}) async {
  final room = context.read<RoomCubit>();
  switch (action) {
    case TableOptionAction.start:
      if (!isCaptain) return;
      final result = await showDialog<GameSettingsResult>(
        context: context,
        builder: (_) => GameSettingsDialog(game: game, defaultTarget: _defaultTarget(game)),
      );
      if (result != null && context.mounted) {
        await room.startGame(targetScore: result.targetScore, rules: result.rules);
      }
      break;
    case TableOptionAction.stop:
      if (isCaptain) await room.stopGame();
      break;
    case TableOptionAction.addBot:
      if (isCaptain && !playing) await room.addBot();
      break;
    case TableOptionAction.removeBot:
      if (isCaptain && !playing) await room.removeBot();
      break;
    case TableOptionAction.leaveTable:
      await room.leaveRoom();
      break;
  }
}

Future<void> executeTableMenuAction(
  BuildContext context,
  TableOptionAction action, {
  required bool isCaptain,
  required bool playing,
  required String game,
}) => executeTableOptionAction(context, action, isCaptain: isCaptain, playing: playing, game: game);

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
