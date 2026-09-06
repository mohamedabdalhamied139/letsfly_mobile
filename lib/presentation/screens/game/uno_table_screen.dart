import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/uno_card_model.dart';
import '../../../data/models/uno_game_state_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/uno_game_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../../core/localization/localization_service.dart';
import '../../../data/models/chat_message_model.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_navigation_menu.dart';
class UnoTableScreen extends StatelessWidget {
  const UnoTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<UnoGameBloc>(
      create: (_) => UnoGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _UnoTableView(),
    );
  }
}
class _UnoTableView extends StatefulWidget {
  const _UnoTableView();
  @override
  State<_UnoTableView> createState() => _UnoTableViewState();
}
class _UnoTableViewState extends State<_UnoTableView> {
  bool _isLogOpen = false;
  void _toggleLog(BuildContext context, List<ChatMessageModel> chatMessages) {
    final announcer = context.read<AccessibilityAnnouncer>();
    setState(() {
      _isLogOpen = !_isLogOpen;
    });
    if (_isLogOpen) {
      announcer.announce('تم فتح السجل');
      final items = chatMessages
          .map(
            (msg) => ActivityItem(
              text: '${msg.sender}: ${msg.text}',
              category: ActivityCategory.tableChat,
              timestamp: msg.timestamp,
            ),
          )
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
  void _showWildColorPicker(BuildContext context, UnoCardModel card) {
    final blocState = context.read<UnoGameBloc>().state;
    final index = blocState is UnoGamePlaying ? blocState.game.hand.indexWhere((c) => c.cardId == card.cardId) : -1;
    if (index < 0) return;
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
                const AccessibleHeader('اختر لون الكارت الحر الجديد:'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildColorChoice(
                      context,
                      ctx,
                      card,
                      'red',
                      'أحمر (Red)',
                      AppColors.unoRed,
                    ),
                    const SizedBox(width: 12),
                    _buildColorChoice(
                      context,
                      ctx,
                      card,
                      'blue',
                      'أزرق (Blue)',
                      AppColors.unoBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildColorChoice(
                      context,
                      ctx,
                      card,
                      'green',
                      'أخضر (Green)',
                      AppColors.unoGreen,
                    ),
                    const SizedBox(width: 12),
                    _buildColorChoice(
                      context,
                      ctx,
                      card,
                      'yellow',
                      'أصفر (Yellow)',
                      AppColors.unoYellow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildColorChoice(
    BuildContext context,
    BuildContext sheetContext,
    UnoCardModel card,
    String colorCode,
    String label,
    Color color,
  ) {
    return Expanded(
      child: SizedBox(
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(sheetContext);
            context.read<UnoGameBloc>().add(
              UnoPlayCardExplicit(card.cardId, chosenColor: colorCode),
            );
          },
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
  Widget _tableNavigation(BuildContext context) {
    return IconButton(
      tooltip: 'قائمة التنقل',
      onPressed: () async {
        final action = await showTableNavigationMenu(context, game: 'UNO');
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
          game: 'UNO',
        );
        if (action == TableOptionAction.leaveTable && context.mounted)
          Navigator.of(context).maybePop();
      },
      icon: const Icon(Icons.more_vert),
    );
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain =
        roomState is RoomActive && roomState.room.isHost(currentUserId);
    return BlocConsumer<UnoGameBloc, UnoGameState>(
      listener: (context, state) {
        if (state is UnoGamePlaying && state.wildPendingCard != null) {
          _showWildColorPicker(context, state.wildPendingCard!);
        }
      },
      builder: (context, state) {
        if (state is UnoGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة UNO'),
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
        if (state is UnoGamePlaying) {
          final game = state.game;
          final topCard = game.topCard;
          final isMyTurn = state.isMyTurn;
          final hand = state.sortedHand;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive
              ? roomState.chatMessages
              : <ChatMessageModel>[];
          final topDesc =
              topCard?.getLocalizedLabel(
                context.read<LocalizationService>().currentLocale.languageCode,
              ) ??
              'لا يوجد كارت';
          final colorDesc = _getArabicColorName(game.currentColor);
          return LetsFlyGestureWrapper(
            handler: LetsFlyGestureHandler(
              onSwipeDown: () {
                if (isMyTurn) {
                  context.read<UnoGameBloc>().add(UnoDrawCard());
                } else {
                  announcer.announce('ليس دورك الآن');
                }
              },
              onSwipeUp: () {
                context.read<UnoGameBloc>().add(UnoCallUno());
              },
              onSwipeRight: () {
                _toggleLog(context, chatMessages);
              },
            ),
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  isMyTurn
                      ? 'دورك الآن للعب!'
                      : 'طاولة UNO • دور ${game.currentPlayerName}',
                ),
                backgroundColor: isMyTurn
                    ? AppColors.unoGreen.withOpacity(0.3)
                    : AppColors.surface,
                actions: [
                  _tableNavigation(context),
                  _tableOptions(context, isCaptain, true),
                ],
              ),
              floatingActionButton: const TableVoiceButton(),
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: MediaQuery.of(context).accessibleNavigation
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    children: [
                      // 1. Table Status
                      ListTile(
                        title: const Text(
                          'حالة الطاولة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        subtitle: Text(
                          'الكارت على الأرض: $topDesc\nاللون المطلوب: $colorDesc\nالدور الحالي للاعب: ${game.currentPlayerName}',
                        ),
                        onTap: () {
                          announcer.announce(
                            'الكارت على الأرض: $topDesc، اللون المطلوب: $colorDesc، الدور الحالي: ${game.currentPlayerName}',
                          );
                        },
                      ),
                      const Divider(),
                      // 2. Scores
                      ExpansionTile(
                        title: Text(
                          'نتائج اللاعبين (${game.players.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: game.players
                            .map(
                              (p) => ListTile(
                                title: Text(p.name),
                                trailing: Text(
                                  '${p.cardCount} كروت',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(),
                      // 3. Hand
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'كروت يدك (${hand.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (hand.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'يدك فارغة!',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      else
                        ...hand.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final card = entry.value;
                          final playable = card.isPlayable(
                            topCard,
                            game.currentColor,
                          );
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: card.getUiColor(),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(
                                card.getLocalizedLabel(
                                  context
                                      .read<LocalizationService>()
                                      .currentLocale
                                      .languageCode,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: playable
                                  ? const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                    )
                                  : null,
                              onTap: () {
                                if (isMyTurn) {
                                  if (playable) {
                                    context.read<UnoGameBloc>().add(
                                      UnoPlayCardExplicit(card.cardId),
                                    );
                                  } else {
                                    announcer.announce(
                                      'لا يمكنك لعب هذا الكارت الآن',
                                    );
                                  }
                                } else {
                                  announcer.announce('ليس دورك للعب');
                                }
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  String _getArabicColorName(String color) {
    switch (color) {
      case 'red':
        return 'أحمر';
      case 'blue':
        return 'أزرق';
      case 'green':
        return 'أخضر';
      case 'yellow':
        return 'أصفر';
      case 'orange':
        return 'برتقالي';
      case 'purple':
        return 'بنفسجي';
      case 'pink':
        return 'وردي';
      case 'teal':
        return 'تركوازي';
      default:
        return color.isEmpty ? 'غير محدد' : color;
    }
  }
}
