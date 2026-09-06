import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/domino_state_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/domino_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_navigation_menu.dart';
class DominoTableScreen extends StatelessWidget {
  const DominoTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<DominoGameBloc>(
      create: (_) => DominoGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _DominoTableView(),
    );
  }
}
class _DominoTableView extends StatefulWidget {
  const _DominoTableView();
  @override
  State<_DominoTableView> createState() => _DominoTableViewState();
}
class _DominoTableViewState extends State<_DominoTableView> {
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
  void _showSidePicker(BuildContext context, DominoHandTile tile, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AccessibleHeader('اختر الجهة التي تريد اللعب عليها:'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSideChoice(context, ctx, 'left', 'يسار (Left)'),
                    const SizedBox(width: 12),
                    _buildSideChoice(context, ctx, 'right', 'يمين (Right)'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildSideChoice(
    BuildContext context,
    BuildContext sheetContext,
    String side,
    String label,
  ) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        hint: 'اختيار الجهة',
        child: SizedBox(
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(sheetContext);
              context.read<DominoGameBloc>().add(
                    DominoPlaySelectedTile(side: side),
                  );
            },
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
  Widget _tableNavigation(BuildContext context) {
    return IconButton(
      tooltip: 'قائمة التنقل',
      onPressed: () async {
        final action = await showTableNavigationMenu(context, game: 'DOMINO');
        if (!context.mounted || action == null) return;
        await executeTableNavAction(
          context,
          action,
          onOpenChat: () {
            final roomState = context.read<RoomCubit>().state;
            final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
            _toggleLog(context, chatMessages);
          },
        );
      },
      icon: const Icon(Icons.explore_outlined),
    );
  }
  Widget _tableOptions(BuildContext context, bool isCaptain, bool playing) {
    return IconButton(
      tooltip: 'خيارات الطاولة',
      onPressed: () async {
        final action = await showTableOptionsMenu(
          context,
          isCaptain: isCaptain,
          playing: playing,
        );
        if (!context.mounted || action == null) return;
        await executeTableMenuAction(
          context,
          action,
          isCaptain: isCaptain,
          playing: playing,
          game: 'DOMINO',
        );
        if (action == TableOptionAction.leaveTable && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      icon: const Icon(Icons.more_vert),
    );
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain = roomState is RoomActive && roomState.room.isHost(currentUserId);
    return BlocBuilder<DominoGameBloc, DominoGameState>(
      builder: (context, state) {
        if (state is DominoGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة الدومينو'),
              actions: [
                _tableNavigation(context),
                _tableOptions(context, isCaptain, false),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('جاري مزامنة حالة اللعبة مع الخادم...'),
                ],
              ),
            ),
          );
        }
        if (state is DominoGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final hand = game.hand;
          final selectedTile = state.selectedTile;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => _toggleLog(context, chatMessages),
            onSwipeLeft: () {
              if (game.leftEnd != null && game.rightEnd != null) {
                if (game.openEndsSum != null) {
                  announcer.announce('${game.leftEnd}/${game.rightEnd}، المجموع ${game.openEndsSum}');
                } else {
                  announcer.announce('${game.leftEnd}/${game.rightEnd}');
                }
              } else {
                announcer.announce('فارغة');
              }
            },
            onSwipeDown: () {
              if (isMyTurn) {
                if (game.canDraw) {
                  context.read<DominoGameBloc>().add(DominoDrawTile());
                } else if (game.canPass) {
                  context.read<DominoGameBloc>().add(DominoPassTurn());
                } else {
                  announcer.announce('لا يمكنك السحب أو التمرير الآن');
                }
              } else {
                announcer.announce('ليس دورك');
              }
            },
            onSwipeUp: () {
              final curr = game.currentPlayerName;
              announcer.announce(curr.isNotEmpty ? 'دور $curr' : 'غير محدد');
            },
            onDoubleTap: () {
              if (isMyTurn && selectedTile != null && selectedTile.isValid) {
                if (selectedTile.validSides.length > 1) {
                  _showSidePicker(context, selectedTile, selectedTile.index);
                } else {
                  context.read<DominoGameBloc>().add(const DominoPlaySelectedTile());
                }
              } else if (!isMyTurn) {
                announcer.announce('ليس دورك');
              } else if (selectedTile != null && !selectedTile.isValid) {
                announcer.announce('القطعة المحددة غير صالحة للعب');
              }
            },
          );
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'لوحة التحكم بالإيماءات لطاولة الدومينو',
            child: Scaffold(
              appBar: AppBar(
                title: Text(isMyTurn ? 'دورك الآن للعب!' : 'طاولة الدومينو • دور ${game.currentPlayerName}'),
                backgroundColor: isMyTurn ? AppColors.primary.withOpacity(0.3) : AppColors.surface,
                actions: [
                  _tableNavigation(context),
                  _tableOptions(context, isCaptain, true),
                ],
              ),
              floatingActionButton: const TableVoiceButton(),
              body: Column(
                children: [
                  // 1. Table Top Area
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 2),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('أطراف الطاولة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Text(
                                      game.leftEnd != null && game.rightEnd != null
                                          ? '${game.leftEnd} - ${game.rightEnd}'
                                          : 'فارغة',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (game.openEndsSum != null) ...[
                                      const SizedBox(height: 4),
                                      Text('مجموع الأطراف: ${game.openEndsSum}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الدور الحالي: ${game.currentPlayerName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMyTurn ? AppColors.primary : AppColors.accent,
                                      fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'القطع على الطاولة: ${game.boardCount}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    'بنك السحب: ${game.boneyardCount}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (game.lastAction.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            game.lastAction,
                            style: const TextStyle(color: AppColors.accent, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 2. Opponents Bar
                  Container(
                    height: 48,
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.players.length,
                      itemBuilder: (context, idx) {
                        final p = game.players[idx];
                        final isTurn = p.userId == game.currentPlayerId;
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
                              '${p.name}: ${p.tileCount} قطع | نقاط: ${p.score}',
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
                  const Divider(height: 1),
                  // 3. Hand Presentation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AccessibleHeader('قطعك (${hand.length})'),
                        if (isMyTurn && game.canDraw)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('سحب'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.read<DominoGameBloc>().add(DominoDrawTile()),
                          )
                        else if (isMyTurn && game.canPass)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.skip_next, size: 16),
                            label: const Text('باص'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.read<DominoGameBloc>().add(DominoPassTurn()),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: hand.isEmpty
                        ? const Center(
                            child: Text('يدك فارغة!', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: hand.length,
                            itemBuilder: (context, idx) {
                              final tile = hand[idx];
                              final isSelected = idx == state.selectedIndex;
                              String semanticsHint = 'قطعة دومينو';
                              if (!tile.isValid) {
                                semanticsHint = 'القطعة غير صالحة للعب الآن';
                              }
                              return Semantics(
                                button: true,
                                selected: isSelected,
                                label: '${tile.label}${tile.isValid ? '، قابلة للعب' : ''}',
                                hint: semanticsHint,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.5),
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
                                      if (!tile.isValid) {
                                        announcer.announce('القطعة غير صالحة للعب الآن');
                                        return;
                                      }
                                      if (tile.validSides.length > 1) {
                                        _showSidePicker(context, tile, idx);
                                      } else {
                                        context.read<DominoGameBloc>().add(DominoPlayTileExplicit(idx));
                                      }
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.surface,
                                      child: Text(
                                        tile.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      'القطعة: ${tile.label}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      tile.isValid ? 'صالحة للعب' : 'غير صالحة',
                                      style: TextStyle(
                                        color: tile.isValid ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.white)
                                        : (tile.isValid
                                            ? const Icon(Icons.play_circle_outline, color: Colors.white70)
                                            : null),
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
