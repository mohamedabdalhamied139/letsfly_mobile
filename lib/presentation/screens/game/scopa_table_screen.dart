import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/scopa_state_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/scopa_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
class ScopaTableScreen extends StatelessWidget {
  const ScopaTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<ScopaGameBloc>(
      create: (_) => ScopaGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _ScopaTableView(),
    );
  }
}
class _ScopaTableView extends StatefulWidget {
  const _ScopaTableView();
  @override
  State<_ScopaTableView> createState() => _ScopaTableViewState();
}
class _ScopaTableViewState extends State<_ScopaTableView> {
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
    return BlocBuilder<ScopaGameBloc, ScopaGameState>(
      builder: (context, state) {
        if (state is ScopaGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة إسكوبا'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'SCOPA');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'SCOPA'),
          );
        }
        if (state is ScopaGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final hand = game.myHand;
          final tableCards = game.tableCards;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => _toggleLog(context, chatMessages),
            onSwipeLeft: () {
              if (tableCards.isEmpty) {
                announcer.announce('الطاولة فارغة');
              } else {
                final names = tableCards.map((c) => c.arabicName).join(' و ');
                announcer.announce('الطاولة بها: $names');
              }
            },
            onSwipeDown: () {
              announcer.announce('بطاقات الديك: ${game.deckCount}');
            },
            onSwipeUp: () {
              if (isMyTurn) {
                announcer.announce('دورك الآن للعب');
              } else {
                announcer.announce('الدور الحالي للاعب: ${game.currentTurnName}');
              }
            },
            onDoubleTap: () {
              if (isMyTurn) {
                context.read<ScopaGameBloc>().add(ScopaPlaySelectedCard());
              }
            },
          );
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'لوحة التحكم بالإيماءات لطاولة إسكوبا',
            child: Scaffold(
              appBar: AppBar(
                title: Text(isMyTurn ? 'دورك الآن للعب!' : 'طاولة إسكوبا • دور ${game.currentTurnName}'),
                backgroundColor: isMyTurn ? AppColors.unoGreen.withOpacity(0.3) : AppColors.surface,
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'SCOPA');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                ],
              ),
              floatingActionButton: const TableVoiceButton(),
              body: Column(
                children: [
                  // Game Status & Score
                  Container(
                    color: AppColors.surfaceVariant.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الجولة: ${game.roundNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('الهدف: ${game.targetScore}'),
                        Text('الديك: ${game.deckCount}'),
                        Text('مأكولاتك: ${game.myCapturedCount}'),
                      ],
                    ),
                  ),
                  // Opponents Bar
                  Container(
                    height: 56,
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.players.length,
                      itemBuilder: (context, idx) {
                        final p = game.players[idx];
                        final isTurn = p.userId == game.currentTurnId;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isTurn ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: isTurn ? Border.all(color: AppColors.primary) : null,
                          ),
                          child: Center(
                            child: Text(
                              '${p.name}: ${p.score} نقطة • ${p.handCount} كروت',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                                color: isTurn ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (game.lastAction.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        game.lastAction,
                        style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Divider(height: 1),
                  // Table Cards
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AccessibleHeader('أوراق الطاولة'),
                  ),
                  Expanded(
                    flex: 1,
                    child: tableCards.isEmpty
                        ? const Center(
                            child: Text('الطاولة فارغة', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: tableCards.length,
                            itemBuilder: (context, idx) {
                              final card = tableCards[idx];
                              return Semantics(
                                label: card.arabicName,
                                child: Card(
                                  color: AppColors.surface,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Icon(Icons.aspect_ratio, color: Colors.white, size: 18),
                                    ),
                                    title: Text(card.arabicName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  // Hand Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: AccessibleHeader('كروت يدك (${hand.length})'),
                  ),
                  Expanded(
                    flex: 1,
                    child: hand.isEmpty
                        ? const Center(
                            child: Text('يدك فارغة!', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: hand.length,
                            itemBuilder: (context, idx) {
                              final card = hand[idx];
                              final isSelected = idx == state.selectedIndex;
                              return Semantics(
                                button: true,
                                selected: isSelected,
                                label: card.arabicName,
                                hint: 'كارت للعب',
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      if (!isMyTurn) {
                                        announcer.announce('ليس دورك للعب');
                                        return;
                                      }
                                      context.read<ScopaGameBloc>().add(ScopaPlayCardExplicit(idx));
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected ? AppColors.primary : Colors.grey[700],
                                      child: const Icon(Icons.style, color: Colors.white, size: 20),
                                    ),
                                    title: Text(
                                      card.arabicName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                                        : null,
                                  ),
                                ),
                              );
                            },
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
