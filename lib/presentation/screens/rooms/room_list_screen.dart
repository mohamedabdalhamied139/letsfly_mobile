import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/accessibility/accessible_widgets.dart';

import '../../../core/constants/app_colors.dart';

import '../../../core/localization/app_localizations.dart';

import '../../bloc/lobby_cubit.dart';

import '../../bloc/room_cubit.dart';
import '../../../data/models/room_model.dart';
import 'room_lobby_screen.dart';



class RoomListScreen extends StatefulWidget {

  const RoomListScreen({super.key});



  @override

  State<RoomListScreen> createState() => _RoomListScreenState();

}



class _RoomListScreenState extends State<RoomListScreen> {

  @override

  void initState() {

    super.initState();

    context.read<LobbyCubit>().loadRooms();

  }



  void _showCreateRoomDialog() {

    showDialog(

      context: context,

      builder: (ctx) {

        String selectedGame = 'UNO';

        return StatefulBuilder(

          builder: (context, setStateDialog) {

            return AlertDialog(

              backgroundColor: AppColors.surface,

              title: const Text('إنشاء طاولة جديدة'),

              content: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  DropdownButtonFormField<String>(

                    value: selectedGame,

                    dropdownColor: AppColors.surfaceVariant,

                    decoration: const InputDecoration(

                      labelText: 'اختر اللعبة',

                      border: OutlineInputBorder(),

                    ),

                    items: const [
                      DropdownMenuItem(value: 'UNO', child: Text('UNO (أونو)')),
                      DropdownMenuItem(value: 'DOMINO', child: Text('DOMINO (دومينو)')),
                      DropdownMenuItem(value: 'AMERICAN_DOMINO', child: Text('AMERICAN DOMINO (الدومينو الأمريكاني)')),
                      DropdownMenuItem(value: 'FARKLE', child: Text('FARKLE (فاركل)')),
                      DropdownMenuItem(value: 'SCOPA', child: Text('SCOPA (إسكوبا)')),
                      DropdownMenuItem(value: 'SNAKES_LADDERS', child: Text('SNAKES & LADDERS (السلم والثعبان)')),
                      DropdownMenuItem(value: 'NINETY_NINE', child: Text('99 (تسعة وتسعون)')),
                      DropdownMenuItem(value: 'TENNIS', child: Text('TENNIS (تنس)')),
                      DropdownMenuItem(value: 'THIEF_HUNT', child: Text('THIEF HUNT (مطاردة اللص)')),
                    ],

                    onChanged: (val) {

                      if (val != null) {

                        setStateDialog(() => selectedGame = val);

                      }

                    },

                  ),

                ],

              ),

              actions: [

                TextButton(

                  onPressed: () => Navigator.pop(ctx),

                  child: const Text('إلغاء'),

                ),

                ElevatedButton(

                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),

                  onPressed: () async {

                    Navigator.pop(ctx);

                    final newRoom = await context.read<LobbyCubit>().createRoom(game: selectedGame);

                    if (newRoom != null && mounted) {

                      _enterRoom(newRoom.roomId);

                    }

                  },

                  child: const Text('إنشاء ودخول'),

                ),

              ],

            );

          },

        );

      },

    );

  }



  void _enterRoom(String roomId, {RoomModel? initialRoom}) {

    context.read<RoomCubit>().enterRoom(roomId, initialRoom: initialRoom);

    Navigator.push(

      context,

      MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('الطاولات المتاحة حاليًا')),

      body: BlocBuilder<LobbyCubit, LobbyState>(

        builder: (context, state) {

          if (state is LobbyLoading) return const Center(child: CircularProgressIndicator());

          if (state is LobbyError) return Center(child: AccessibleButton(label: 'إعادة المحاولة', onPressed: () => context.read<LobbyCubit>().loadRooms()));

          if (state is! LobbyLoaded) return const SizedBox.shrink();

          if (state.rooms.isEmpty) return const Center(child: Text('لا توجد طاولات متاحة حاليًا.'));

          return ListView.builder(

            itemCount: state.rooms.length,

            itemBuilder: (_, index) {

              final room = state.rooms[index];

              return ListTile(

                title: Text(room.game),

                subtitle: Text('${room.hostName} — ${room.players.length}'),

                onTap: () => _enterRoom(room.roomId),

              );

            },

          );

        },

      ),

    );

  }

}

