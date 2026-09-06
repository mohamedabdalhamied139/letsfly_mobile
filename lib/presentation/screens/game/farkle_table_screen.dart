import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:letsfly_mobile/presentation/bloc/farkle_game_bloc.dart';
import 'package:letsfly_mobile/data/models/farkle_state_model.dart';
import 'package:letsfly_mobile/core/accessibility/gesture_controller.dart';
import 'package:letsfly_mobile/core/constants/app_colors.dart';
import 'package:letsfly_mobile/core/accessibility/accessible_widgets.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
import '../../bloc/room_cubit.dart';
class FarkleTableScreen extends StatelessWidget {
  final int myUserId;
  const FarkleTableScreen({
    super.key,
    required this.myUserId,
  });
  @override
  Widget build(BuildContext context) {
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain = roomState is RoomActive && roomState.room.isHost(myUserId);
    return BlocBuilder<FarkleGameBloc, FarkleGameState>(
      builder: (context, state) {
        if (state is FarkleGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة فاركل'),
              actions: [
                IconButton(
                  tooltip: 'قائمة التنقل',
                  icon: const Icon(Icons.menu),
                  onPressed: () async {
                    final action = await showTableNavMenu(context);
                    if (!context.mounted || action == null) return;
                    await executeTableNavAction(context, action);
                    if (action == TableNavAction.exitLetsFly && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                IconButton(
                  tooltip: 'خيارات الطاولة',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    final action = await showTableOptionsMenu(context, isCaptain: isCaptain, playing: false);
                    if (!context.mounted || action == null) return;
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'FARKLE');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            backgroundColor: AppColors.background,
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'FARKLE'),
          );
        }
        if (state is FarkleGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeDown: () {
              // Quick action: bank if possible
              if (isMyTurn && game.turnScore >= game.minBank && !game.mustScoreBeforeRoll) {
                context.read<FarkleGameBloc>().add(FarkleActionBank());
              }
            },
            onSwipeUp: () {
              // Quick action: roll if possible
              if (isMyTurn && game.canRoll && !game.mustScoreBeforeRoll) {
                context.read<FarkleGameBloc>().add(FarkleActionRoll());
              }
            },
          );
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'شاشة لعبة فاركل',
            child: Scaffold(
              appBar: AppBar(
                title: Text(isMyTurn ? 'دورك للعب!' : 'دور ${game.currentPlayerName}'),
                actions: [
                IconButton(
                  tooltip: 'قائمة التنقل',
                  icon: const Icon(Icons.menu),
                  onPressed: () async {
                    final action = await showTableNavMenu(context);
                    if (!context.mounted || action == null) return;
                    await executeTableNavAction(context, action);
                    if (action == TableNavAction.exitLetsFly && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                IconButton(
                  tooltip: 'خيارات الطاولة',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    final action = await showTableOptionsMenu(context, isCaptain: isCaptain, playing: true);
                    if (!context.mounted || action == null) return;
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'FARKLE');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                ],
              ),
              backgroundColor: AppColors.background,
              floatingActionButton: const TableVoiceButton(),
              body: Column(
                children: [
                  // 1. Status Bar (Target score, turn score)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الهدف: ${game.targetScore}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                        ),
                        Text(
                          'مجموع الدور: ${game.turnScore}',
                          style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // 2. Scores List
                  Container(
                    height: 50,
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.scores.length,
                      itemBuilder: (context, idx) {
                        final entry = game.scores.entries.elementAt(idx);
                        final uid = entry.key;
                        final score = entry.value;
                        final name = game.playerNames[uid] ?? 'لاعب';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: Text(
                            '$name: $score',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  // 3. Current Dice
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AccessibleHeader('النرد الحالي'),
                        const SizedBox(height: 8),
                        if (game.dice.isEmpty)
                          const Text('لا يوجد نرد.', style: TextStyle(color: AppColors.textSecondary))
                        else
                          Wrap(
                            spacing: 8,
                            children: game.dice.map((d) => Semantics(
                              label: 'نرد بقيمة $d',
                              child: Chip(
                                label: Text('$d', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                backgroundColor: AppColors.surface,
                              ),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 4. Actions & Combinations (Only if my turn)
                  if (isMyTurn)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: AccessibleHeader('الإجراءات المتاحة'),
                          ),
                          // Roll & Bank Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                if (game.canRoll && !game.mustScoreBeforeRoll)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context.read<FarkleGameBloc>().add(FarkleActionRoll());
                                      },
                                      child: const Text('رمي النرد'),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (game.turnScore >= game.minBank && !game.mustScoreBeforeRoll)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context.read<FarkleGameBloc>().add(FarkleActionBank());
                                      },
                                      child: Text('إيداع ${game.turnScore} نقطة'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Combinations
                          if (game.availableCombinations.isNotEmpty)
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemCount: game.availableCombinations.length,
                                itemBuilder: (context, idx) {
                                  final combo = game.availableCombinations[idx];
                                  return Semantics(
                                    button: true,
                                    label: 'تسجيل ${combo.label}',
                                    child: Card(
                                      color: AppColors.surface,
                                      child: ListTile(
                                        title: Text(combo.label, style: const TextStyle(color: AppColors.textPrimary)),
                                        subtitle: Text('${combo.points} نقطة', style: const TextStyle(color: AppColors.accent)),
                                        trailing: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                                        onTap: () {
                                          context.read<FarkleGameBloc>().add(FarkleActionScore(combo.indices));
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            const Expanded(
                              child: Center(
                                child: Text('لا توجد تجميعات متاحة.', style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Text(
                          'في انتظار اللاعب الآخر...',
                          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
