import 'package:flutter/material.dart';
import '../../widgets/table_voice_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/accessibility/gesture_controller.dart';
import '../../../core/audio/table_audio_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/thief_hunt_state_model.dart';
import '../../../data/repositories/room_ws_service.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/room_cubit.dart';
import '../../bloc/thief_hunt_game_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../widgets/activity/activity_log_drawer.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_nav_menu.dart';
import '../../widgets/table_waiting_view.dart';
class ThiefHuntTableScreen extends StatelessWidget {
  const ThiefHuntTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomWsService = context.read<RoomWsService>();
    final audioService = context.read<TableAudioService>();
    return BlocProvider<ThiefHuntGameBloc>(
      create: (_) => ThiefHuntGameBloc(
        roomWsService: roomWsService,
        audioService: audioService,
        myUserId: currentUserId,
      ),
      child: const _ThiefHuntTableView(),
    );
  }
}
class _ThiefHuntTableView extends StatefulWidget {
  const _ThiefHuntTableView();
  @override
  State<_ThiefHuntTableView> createState() => _ThiefHuntTableViewState();
}
class _ThiefHuntTableViewState extends State<_ThiefHuntTableView> {
  bool _isLogOpen = false;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }
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
  void _submitInput(BuildContext context, String mode) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final floor = int.tryParse(text);
    if (floor == null || floor < 1 || floor > 10) {
      context.read<AccessibilityAnnouncer>().announce('يرجى كتابة رقم طابق بين 1 و 10', priority: AnnouncePriority.assertive);
      return;
    }
    _inputController.clear();
    if (mode == 'choose_floor') {
      context.read<ThiefHuntGameBloc>().add(ThiefHuntChooseFloor(floor));
    } else if (mode == 'answering') {
      context.read<ThiefHuntGameBloc>().add(ThiefHuntSubmitAnswer(floor));
    }
    _inputFocus.unfocus();
  }
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.id : 0;
    final roomState = context.watch<RoomCubit>().state;
    final isCaptain = roomState is RoomActive && roomState.room.isHost(currentUserId);
    return BlocConsumer<ThiefHuntGameBloc, ThiefHuntGameState>(
      listener: (context, state) {
        if (state is ThiefHuntGamePlaying) {
          if (state.game.phase == 'answering' && !state.game.isThief) {
             // Request focus
             if (ModalRoute.of(context)?.isCurrent == true) {
               FocusScope.of(context).requestFocus(_inputFocus);
             }
          }
        }
      },
      builder: (context, state) {
        if (state is ThiefHuntGameWaiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('طاولة صيد اللص'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: false, game: 'THIEF_HUNT');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
            floatingActionButton: const TableVoiceButton(),
            body: const TableWaitingView(game: 'THIEF_HUNT'),
          );
        }
        if (state is ThiefHuntGamePlaying) {
          final game = state.game;
          final isMyTurn = state.isMyTurn;
          final announcer = context.read<AccessibilityAnnouncer>();
          final chatMessages = roomState is RoomActive ? roomState.chatMessages : <ChatMessageModel>[];
          final gestureHandler = LetsFlyGestureHandler(
            onSwipeRight: () => _toggleLog(context, chatMessages),
            onSwipeLeft: () {
              String boardInfo = 'الجولة ${game.roundNumber}. ';
              if (game.startFloor != null) boardInfo += 'الطابق الابتدائي ${game.startFloor}. ';
              if (game.directions.isNotEmpty) boardInfo += 'الاتجاهات: ${game.directions.join("، ")}. ';
              if (game.finalFloor != null) boardInfo += 'الطابق النهائي ${game.finalFloor}. ';
              if (boardInfo.isEmpty) boardInfo = 'المعلومات غير متاحة بعد';
              announcer.announce(boardInfo);
            },
            onSwipeDown: () {
               announcer.announce(game.lastAction.isNotEmpty ? game.lastAction : 'لا يوجد حدث أخير');
            },
            onSwipeUp: () {
              if (isMyTurn) {
                announcer.announce('دورك الآن لتسجيل إجابتك');
              } else {
                announcer.announce(game.phase == 'waiting' ? 'في الانتظار' : 'جاري اللعب');
              }
            },
            onDoubleTap: () {
               if (game.phase == 'escape' && !game.isThief) {
                 context.read<ThiefHuntGameBloc>().add(ThiefHuntBeginAnswering());
               }
            },
          );
          String promptText = '';
          if (game.phase == 'choose_floor' && game.isThief) {
             promptText = 'أنت اللص! اختر طابقًا للهروب (1 - 10)';
          } else if (game.phase == 'answering' && !game.isThief) {
             promptText = 'أين اللص؟ اكتب رقم الطابق (1 - 10)';
          } else if (game.phase == 'escape' && !game.isThief) {
             promptText = 'اضغط مرتين بإصبع واحد للبدء بالإجابة (إذا كنت مستعدًا)';
          }
          return LetsFlyGestureWrapper(
            handler: gestureHandler,
            semanticLabel: 'طاولة صيد اللص',
            child: Scaffold(
              appBar: AppBar(
                title: Text('صيد اللص - جولة ${game.roundNumber} / ${game.totalRounds}'),
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
                    await executeTableOptionAction(context, action, isCaptain: isCaptain, playing: true, game: 'THIEF_HUNT');
                    if (action == TableOptionAction.leaveTable && context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                ],
              ),
              floatingActionButton: const TableVoiceButton(),
              body: Column(
                children: [
                  // Game Status & Input Area
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'المرحلة: ${_getPhaseArabic(game.phase)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (game.lastAction.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            game.lastAction,
                            style: const TextStyle(color: AppColors.accent, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (promptText.isNotEmpty) ...[
                           const SizedBox(height: 16),
                           Text(
                             promptText,
                             style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold),
                             textAlign: TextAlign.center,
                           ),
                        ],
                        if (isMyTurn) ...[
                           const SizedBox(height: 16),
                           Semantics(
                             label: promptText,
                             child: TextField(
                               controller: _inputController,
                               focusNode: _inputFocus,
                               keyboardType: TextInputType.number,
                               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                               decoration: InputDecoration(
                                 hintText: 'أدخل رقم الطابق',
                                 border: const OutlineInputBorder(),
                                 suffixIcon: IconButton(
                                   icon: const Icon(Icons.send),
                                   onPressed: () => _submitInput(context, game.phase),
                                 ),
                               ),
                               onSubmitted: (_) => _submitInput(context, game.phase),
                             ),
                           ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Players and Scores
                  Expanded(
                    child: ListView(
                      children: [
                        const Padding(
                           padding: EdgeInsets.all(16.0),
                           child: AccessibleHeader('اللاعبين والنقاط'),
                        ),
                        ...game.players.map((p) => ListTile(
                           title: Text(p.name, style: TextStyle(fontWeight: p.eliminated ? FontWeight.normal : FontWeight.bold, decoration: p.eliminated ? TextDecoration.lineThrough : null)),
                           subtitle: Text(p.isThief ? 'اللص' : 'محقق'),
                           trailing: Text('${p.wins} فوز', style: const TextStyle(fontSize: 16)),
                        )),
                        if (game.thiefVirtual)
                          ListTile(
                             title: const Text('اللص الوهمي', style: TextStyle(fontWeight: FontWeight.bold)),
                             trailing: Text('${game.virtualThiefWins} فوز', style: const TextStyle(fontSize: 16)),
                          ),
                        if (game.answers.isNotEmpty) ...[
                           const Padding(
                             padding: EdgeInsets.all(16.0),
                             child: AccessibleHeader('الإجابات المُسجلة'),
                           ),
                           ...game.answers.map((a) => ListTile(
                             title: Text(a.name),
                             trailing: Text('الطابق ${a.floor}', style: const TextStyle(fontSize: 16, color: AppColors.primary)),
                           )),
                        ]
                      ],
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
  String _getPhaseArabic(String phase) {
    switch (phase) {
      case 'waiting': return 'في الانتظار';
      case 'choose_floor': return 'اختيار الطابق';
      case 'escape': return 'الهروب';
      case 'answering': return 'إدخال الإجابات';
      case 'round_result': return 'نتيجة الجولة';
      case 'match_finished': return 'نهاية المباراة';
      default: return phase;
    }
  }
}
