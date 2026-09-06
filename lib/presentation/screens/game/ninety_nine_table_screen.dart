import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/ninety_nine_card_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/ninety_nine_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
class NinetyNineTableScreen extends StatelessWidget {
  const NinetyNineTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<NinetyNineGameBloc>(
      create: (_) => NinetyNineGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _NinetyNineTableView(),
    );
  }
}
class _NinetyNineTableView extends StatefulWidget {
  const _NinetyNineTableView();
  @override
  State<_NinetyNineTableView> createState() => _NinetyNineTableViewState();
}
class _NinetyNineTableViewState extends State<_NinetyNineTableView> {
  bool _isLogOpen = false;
  bool _isChoiceDialogOpen = false;
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
  void _showChoiceDialog(BuildContext context, Map<String, dynamic> pendingChoice) {
    if (_isChoiceDialogOpen) return;
    _isChoiceDialogOpen = true;
    final type = pendingChoice['type'] as String? ?? '';
    final announcer = context.read<AccessibilityAnnouncer>();
    String title = 'اختر القيمة';
    int opt1 = 0, opt2 = 0;
    if (type == '10') {
      title = 'اختر قيمة بطاقة الـ 10';
      opt1 = 10;
      opt2 = -10;
    } else if (type == 'A') {
      title = 'اختر قيمة الآس';
      opt1 = 1;
      opt2 = 11;
    }
    announcer.announce('$title: $opt1 أو $opt2');
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                AccessibleHeader(title),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildChoiceButton(context, ctx, opt1),
                    const SizedBox(width: 12),
                    _buildChoiceButton(context, ctx, opt2),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'إلغاء',
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<NinetyNineGameBloc>().add(NinetyNineCancelChoice());
                      _isChoiceDialogOpen = false;
                    },
                    child: const Text('إلغاء', style: TextStyle(color: AppColors.error, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isChoiceDialogOpen = false;
    });
  }
  Widget _buildChoiceButton(BuildContext context, BuildContext sheetContext, int val) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'اختر $val',
        hint: 'اختيار القيمة',
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
              context.read<NinetyNineGameBloc>().add(NinetyNineMakeChoice(val));
              _isChoiceDialogOpen = false;
            },
            child: Text(
              val > 0 ? '+$val' : '$val',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain = roomState is RoomActive && roomState.room.isHost(currentUserId);
    return BlocConsumer<NinetyNineGameBloc, NinetyNineGameState>(
      listener: (context, state) {
        if (state is NinetyNineGamePlaying && state.game.pendingChoice != null) {
          final pending = state.game.pendingChoice!;
          if (pending['player_id'] == currentUserId) {
            _showChoiceDialog(context, pending);
          }
        }
      },
      builder: (context, state) {
        if (state is NinetyNineGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة تسعة وتسعون'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'NINETY_NINE');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'NINETY_NINE'),
          );
        }
        if (state is NinetyNineGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final hand = game.hand;
          final selectedCard = state.selectedCard;
          final canPlay = isMyTurn && selectedCard != null;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => _toggleLog(context, chatMessages),
            onSwipeLeft: () {
              announcer.announce('المجموع الحالي في الساحة: ${game.pileValue}');
            },
            onSwipeDown: () {
              // Not used in Ninety Nine usually (cards are drawn automatically)
              announcer.announce('لا يوجد سحب يدوي في هذه اللعبة');
            },
            onSwipeUp: () {
              if (isMyTurn) {
                announcer.announce('دورك الآن للعب');
              } else {
                announcer.announce('الدور الحالي للاعب: ${game.currentPlayerName}');
              }
            },
            onDoubleTap: () {
              if (canPlay) {
                context.read<NinetyNineGameBloc>().add(NinetyNinePlaySelectedCard());
              }
            },
          );
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'لوحة التحكم بالإيماءات لطاولة 99',
            child: Scaffold(
              appBar: AppBar(
                title: Text(isMyTurn ? 'دورك الآن للعب!' : 'طاولة 99 • دور ${game.currentPlayerName}'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'NINETY_NINE');
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${game.pileValue}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'المجموع (Pile)',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
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
                                    'اتجاه اللعب: ${game.direction == 1 ? "عادي" : "معكوس"}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'الدور الحالي: ${game.currentPlayerName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMyTurn ? AppColors.unoGreen : AppColors.accent,
                                      fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'عدد الرموز الخاصة بك: ${game.tokens[currentUserId] ?? 0}',
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
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    height: 48,
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.players.length,
                      itemBuilder: (context, idx) {
                        final pMap = game.players[idx] as Map<String, dynamic>;
                        final pId = pMap['id'] as int;
                        final pName = pMap['name'] as String;
                        final pTokens = game.tokens[pId] ?? 0;
                        final isTurn = pId == game.currentPlayerId;
                        final isEliminated = game.eliminated.contains(pId);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isTurn ? AppColors.primary.withOpacity(0.2) : (isEliminated ? Colors.red.withOpacity(0.2) : AppColors.surface),
                            borderRadius: BorderRadius.circular(16),
                            border: isTurn ? Border.all(color: AppColors.primary) : null,
                          ),
                          child: Center(
                            child: Text(
                              '$pName: $pTokens رمز' + (isEliminated ? ' (خارج)' : ''),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AccessibleHeader('كروت يدك (${hand.length})'),
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
                              final card = hand[idx];
                              final isSelected = idx == state.selectedIndex;
                              return Semantics(
                                button: true,
                                selected: isSelected,
                                label: card.getLocalizedLabel('ar'),
                                hint: 'كارت صالح للعب',
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
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
                                      context.read<NinetyNineGameBloc>().add(NinetyNinePlayCardExplicit(idx));
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.white24,
                                      child: Text(
                                        '${card.value}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      card.getLocalizedLabel('ar'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.white)
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
