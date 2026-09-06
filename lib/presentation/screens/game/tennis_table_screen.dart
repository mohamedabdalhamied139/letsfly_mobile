import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/audio/tennis_sound_engine.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/tennis_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
class TennisTableScreen extends StatelessWidget {
  const TennisTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<TennisGameBloc>(
      create: (_) => TennisGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        tennisSoundEngine: TennisSoundEngine(),
        myUserId: currentUserId,
      ),
      child: const _TennisTableView(),
    );
  }
}
class _TennisTableView extends StatefulWidget {
  const _TennisTableView();
  @override
  State<_TennisTableView> createState() => _TennisTableViewState();
}
class _TennisTableViewState extends State<_TennisTableView> {
  bool _isLogOpen = false;
  void _toggleLog(BuildContext context, List<ChatMessageModel> chatMessages) {
    final announcer = context.read<AccessibilityAnnouncer>();
    setState(() {
      _isLogOpen = !_isLogOpen;
    });
    if (_isLogOpen) {
      announcer.announce('تم فتح السجل');
      final items = chatMessages.map((msg) => ActivityItem(
        text: '${msg.sender}: ${msg.text}',
        category: ActivityCategory.tableChat,
        timestamp: msg.timestamp,
      )).toList();
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
    final isCaptain = roomState is RoomActive && roomState.room.isHost(currentUserId);
    final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
    return BlocBuilder<TennisGameBloc, TennisGameState>(
      builder: (context, state) {
        if (state is TennisGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة تنس'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'TENNIS');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'TENNIS'),
          );
        }
        if (state is TennisGamePlaying) {
          final game = state.game;
          final myPlayerIndex = game.players.indexWhere((p) => p.id == currentUserId);
          final myIdx = myPlayerIndex >= 0 ? myPlayerIndex : 0;
          final oppIdx = 1 - myIdx;
          final myPoints = game.score.points[myIdx] ?? '0';
          final oppPoints = game.score.points[oppIdx] ?? '0';
          final myGames = game.score.games[myIdx] ?? 0;
          final oppGames = game.score.games[oppIdx] ?? 0;
          final mySets = game.score.sets[myIdx] ?? 0;
          final oppSets = game.score.sets[oppIdx] ?? 0;
          final announcer = context.read<AccessibilityAnnouncer>();
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => context.read<TennisGameBloc>().add(const TennisMoveLane(1)),
            onSwipeLeft: () => context.read<TennisGameBloc>().add(const TennisMoveLane(-1)),
            onSwipeDown: () => _toggleLog(context, chatMessages),
            onSwipeUp: () => context.read<TennisGameBloc>().add(const TennisServe(0)),
            onDoubleTap: () => context.read<TennisGameBloc>().add(const TennisServe(0)),
          );
          String laneText = state.myLane == -1 ? 'اليسار' : (state.myLane == 1 ? 'اليمين' : 'الوسط');
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'لوحة التنس',
            child: Scaffold(
              appBar: AppBar(
                title: const Text('طاولة التنس'),
                backgroundColor: AppColors.surface,
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'TENNIS');
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
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('أنت', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('النقاط: $myPoints', style: const TextStyle(fontSize: 18)),
                            Text('الأشواط: $myGames'),
                            Text('المجموعات: $mySets'),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('الخصم', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('النقاط: $oppPoints', style: const TextStyle(fontSize: 18)),
                            Text('الأشواط: $oppGames'),
                            Text('المجموعات: $oppSets'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AccessibleHeader('موقعك الحالي: $laneText'),
                          const SizedBox(height: 16),
                          if (state.isMyServe)
                            const Text('دورك للإرسال!', 
                              style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
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
