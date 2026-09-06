import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/snakes_and_ladders_state_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/snakes_and_ladders_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
class SnakesAndLaddersTableScreen extends StatelessWidget {
  const SnakesAndLaddersTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<SnakesAndLaddersGameBloc>(
      create: (_) => SnakesAndLaddersGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _SnakesAndLaddersTableView(),
    );
  }
}
class _SnakesAndLaddersTableView extends StatefulWidget {
  const _SnakesAndLaddersTableView();
  @override
  State<_SnakesAndLaddersTableView> createState() =>
      _SnakesAndLaddersTableViewState();
}
class _SnakesAndLaddersTableViewState
    extends State<_SnakesAndLaddersTableView> {
  bool _isLogOpen = false;
  void _toggleLog(BuildContext context, List<ChatMessageModel> chatMessages) {
    final announcer = context.read<AccessibilityAnnouncer>();
    setState(() {
      _isLogOpen = !_isLogOpen;
    });
    if (_isLogOpen) {
      announcer.announce('تم فتح السجل');
      final items = chatMessages
          .map((msg) => ActivityItem(
                text: '${msg.sender}: ${msg.text}',
                category: ActivityCategory.tableChat,
                timestamp: msg.timestamp,
              ))
          .toList();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ActivityLogDrawer(
          showChatInput: true,
          items: items,
          onSendMessage: (msg) {
            context.read<RoomCubit>().sendChat(msg);
          },
          onClose: () {
            Navigator.of(ctx).pop();
            _toggleLog(context, chatMessages);
          },
        ),
      ).then((_) {
        if (_isLogOpen) {
          setState(() {
            _isLogOpen = false;
          });
          announcer.announce('تم إغلاق السجل');
        }
      });
    } else {
      Navigator.of(context, rootNavigator: true).maybePop();
      announcer.announce('تم إغلاق السجل');
    }
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain =
        roomState is RoomActive && roomState.room.isHost(currentUserId);
    return BlocConsumer<SnakesAndLaddersGameBloc, SnakesAndLaddersGameState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (state is SnakesAndLaddersGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة السلم والثعبان'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'SNAKES_LADDERS');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'SNAKES_LADDERS'),
          );
        }
        if (state is SnakesAndLaddersGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive
              ? roomState.chatMessages
              : <ChatMessageModel>[];
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => _toggleLog(context, chatMessages),
            onSwipeLeft: () {
              context
                  .read<SnakesAndLaddersGameBloc>()
                  .add(SnakesAndLaddersScanRadar());
            },
            onSwipeDown: () {
              final standings = game.players
                  .map((p) => '${p.name} في المربع ${p.position}')
                  .join('، ');
              announcer.announce('مراكز اللاعبين: $standings');
            },
            onSwipeUp: () {
              if (isMyTurn) {
                announcer.announce('دورك الآن للعب. يمكنك رمي النرد.');
              } else {
                announcer.announce(
                    'الدور الحالي للاعب: ${game.currentPlayerName}');
              }
            },
            onDoubleTap: () {
              if (isMyTurn) {
                context
                    .read<SnakesAndLaddersGameBloc>()
                    .add(SnakesAndLaddersRollDice());
              } else {
                announcer.announce('ليس دورك لرمي النرد');
              }
            },
          );
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'لوحة التحكم بالإيماءات لطاولة السلم والثعبان',
            child: Scaffold(
              appBar: AppBar(
                title: Text(isMyTurn
                    ? 'دورك الآن لرمي النرد!'
                    : 'طاولة السلم والثعبان • دور ${game.currentPlayerName}'),
                backgroundColor: isMyTurn
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.surface,
                actions: [
Semantics(
                    label: 'السجل والدردشة',
                    child: IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: 'السجل والدردشة',
                      onPressed: () => _toggleLog(context, chatMessages),
                    ),
                  ),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'SNAKES_LADDERS');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                ],
              ),
              floatingActionButton: const TableVoiceButton(),
              body: Column(
                children: [
                  Container(
                    color: AppColors.surface,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          'طاولة السلم والثعبان',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الدور الحالي: ${game.currentPlayerName}',
                          style: TextStyle(
                            fontSize: 16,
                            color: isMyTurn ? AppColors.success : AppColors.accent,
                            fontWeight:
                                isMyTurn ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (game.extraRoll)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'لعبة إضافية!',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (game.lastAction.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              game.lastAction,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AccessibleHeader('مراكز اللاعبين'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: game.players.length,
                      itemBuilder: (context, idx) {
                        final p = game.players[idx];
                        final isMe = p.userId == currentUserId;
                        return Semantics(
                          label:
                              'اللاعب ${p.name} في المربع ${p.position}. باقي له ${p.distanceToFinish} خطوة للنهاية.',
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: isMe
                                  ? Border.all(color: AppColors.primary)
                                  : null,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isMe
                                    ? AppColors.primary
                                    : AppColors.surfaceVariant,
                                child: Text(
                                  '${p.position}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'باقي للنهاية: ${p.distanceToFinish}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                  if (p.isFrozen)
                                    const Text(
                                      'مجمد ❄️',
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  if (p.hasShield)
                                    const Text(
                                      'درع حماية 🛡️',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (isMyTurn)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Semantics(
                        button: true,
                        label: 'ارمِ النرد',
                        hint: 'رمي النرد',
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              context
                                  .read<SnakesAndLaddersGameBloc>()
                                  .add(SnakesAndLaddersRollDice());
                            },
                            child: const Text(
                              'ارمِ النرد',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
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
