import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/accessibility/accessible_widgets.dart';

import '../../../core/constants/app_colors.dart';

import '../../bloc/auth_bloc.dart';

import '../../bloc/room_cubit.dart';

import '../game/uno_table_screen.dart';
import '../game/domino_table_screen.dart';
import '../game/american_domino_table_screen.dart';
import '../game/farkle_table_screen.dart';
import '../game/ninety_nine_table_screen.dart';
import '../game/scopa_table_screen.dart';
import '../game/snakes_and_ladders_table_screen.dart';
import '../game/tennis_table_screen.dart';
import '../game/thief_hunt_table_screen.dart';




import '../settings/game_settings_dialog.dart';
import '../../widgets/table_options_menu.dart';
import '../../widgets/table_navigation_menu.dart';



class RoomLobbyScreen extends StatefulWidget {

  const RoomLobbyScreen({super.key});



  @override

  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();

}



class _RoomLobbyScreenState extends State<RoomLobbyScreen> {

  final _chatController = TextEditingController();



  @override

  void dispose() {

    _chatController.dispose();

    super.dispose();

  }



  void _sendChat() {

    final text = _chatController.text.trim();

    if (text.isNotEmpty) {

      context.read<RoomCubit>().sendChat(text);

      _chatController.clear();

    }

  }



  int _defaultTarget(String game) => const {

    'UNO': 500, 'THIEF_HUNT': 1, 'FARKLE': 1500, 'DOMINO': 100,

    'AMERICAN_DOMINO': 150, 'SNAKES_LADDERS': 100, 'SCOPA': 11,

    'TENNIS': 1, 'NINETY_NINE': 11,

  }[game] ?? 1;



  bool _canStart(String game, int count) {

    final limits = <String, List<int>>{

      'UNO':[2,10], 'THIEF_HUNT':[2,10], 'FARKLE':[2,10], 'DOMINO':[2,5],

      'AMERICAN_DOMINO':[2,5], 'SNAKES_LADDERS':[2,10], 'SCOPA':[2,6],

      'TENNIS':[2,2], 'NINETY_NINE':[2,10],

    };

    final l=limits[game] ?? const [2,10];

    return count >= l[0] && count <= l[1];

  }



  Future<void> _startWithSettings(String game) async {

    final result = await showDialog<GameSettingsResult>(context: context, builder: (_) => GameSettingsDialog(game: game, defaultTarget: _defaultTarget(game)));

    if (!mounted || result == null) return;

    await context.read<RoomCubit>().startGame(targetScore: result.targetScore, rules: result.rules);

  }



  @override

  Widget build(BuildContext context) {

    final authState = context.watch<AuthBloc>().state;

    final currentUserId = authState is Authenticated ? authState.user.id : 0;

    return BlocConsumer<RoomCubit, RoomState>(

      listener: (context, state) {

        if (state is RoomLeft) Navigator.of(context).pop();

        if (state is RoomActive && state.room.isPlaying()) {

          final game = state.room.game.toUpperCase();

          Widget table;
            switch (game.toLowerCase()) {
              case 'domino': table = const DominoTableScreen(); break;
              case 'american_domino': table = const AmericanDominoTableScreen(); break;
              case 'farkle': table = FarkleTableScreen(myUserId: currentUserId); break;
              case 'ninety_nine': table = const NinetyNineTableScreen(); break;
              case 'scopa': table = const ScopaTableScreen(); break;
              case 'snakes_and_ladders': table = const SnakesAndLaddersTableScreen(); break;
              case 'tennis': table = const TennisTableScreen(); break;
              case 'thief_hunt': table = const ThiefHuntTableScreen(); break;
              default: table = const UnoTableScreen();
            }

          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => table));

        }

      },

      builder: (context, state) {

        if (state is RoomLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        if (state is! RoomActive) return const Scaffold(body: SizedBox.shrink());

        final room = state.room;

        final isCaptain = room.isHost(currentUserId);

        final hasBots = room.players.any((id) => id < 0);

        return Scaffold(

          appBar: AppBar(

            title: Text(room.game),

            actions: [
              Semantics(
                button: true,
                label: 'قائمة التنقل',
                child: IconButton(
                  tooltip: 'قائمة التنقل',
                  icon: const Icon(Icons.explore_outlined),
                  onPressed: () async {
                    final navAction = await showTableNavigationMenu(context, game: room.game);
                    if (!mounted || navAction == null) return;
                    await executeTableNavAction(context, navAction);
                  },
                ),
              ),
              Semantics(
                button: true,
                label: 'خيارات الطاولة',
                child: IconButton(
                  tooltip: 'خيارات الطاولة',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () async {
                    final action = await showTableOptionsMenu(context, isCaptain: isCaptain, playing: room.isPlaying());
                    if (!mounted || action == null) return;
                    await executeTableMenuAction(context, action, isCaptain: isCaptain, playing: room.isPlaying(), game: room.game);
                  },
                ),
              ),
            ],

          ),

          body: SafeArea(

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

                if (state.chatMessages.isNotEmpty)

                  SizedBox(

                    height: 56,

                    child: ListView.builder(

                      reverse: true,

                      itemCount: state.chatMessages.length,

                      itemBuilder: (_, i) {

                        final m = state.chatMessages[state.chatMessages.length - 1 - i];

                        return ListTile(dense: true, title: Text('${m.sender}: ${m.text}'));

                      },

                    ),

                  ),

                if (room.isWaiting() && isCaptain && _canStart(room.game, room.players.length))

                  Padding(

                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),

                    child: TextButton(onPressed: () => _startWithSettings(room.game), child: const Text('بدء اللعبة')),

                  ),

              ],

            ),

          ),

        );

      },

    );

  }



}