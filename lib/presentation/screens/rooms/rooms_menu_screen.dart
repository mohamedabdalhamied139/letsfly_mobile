import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessibility_announcer.dart';
import '../../bloc/lobby_cubit.dart';
import '../../bloc/room_cubit.dart';
import 'room_lobby_screen.dart';
import 'join_rooms_screen.dart';

enum RoomsMenuMode {
  main,
  categories,
  cards,
  dice,
  domino,
  memory,
  sports,
}

class RoomsMenuScreen extends StatefulWidget {
  const RoomsMenuScreen({super.key});

  @override
  State<RoomsMenuScreen> createState() => _RoomsMenuScreenState();
}

class _RoomsMenuScreenState extends State<RoomsMenuScreen> {
  RoomsMenuMode _mode = RoomsMenuMode.main;
  bool _isCreating = false;

  void _enterRoom(String roomId, {dynamic initialRoom}) {
    context.read<RoomCubit>().enterRoom(roomId, initialRoom: initialRoom);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
    );
  }

  void _createGame(String gameCode, String gameName) async {
    if (_isCreating) return;
    _isCreating = true;

    final announcer = context.read<AccessibilityAnnouncer>();
    announcer.announce('جاري إنشاء طاولة ...');
    try {
      final newRoom = await context.read<LobbyCubit>().createRoom(game: gameCode);
      if (newRoom != null && mounted) {
        _enterRoom(newRoom.roomId, initialRoom: newRoom);
      }
    } finally {
      if (mounted) {
        _isCreating = false;
      }
    }
  }

  String get _currentTitle {
    switch (_mode) {
      case RoomsMenuMode.main:
        return 'الطاولات';
      case RoomsMenuMode.categories:
        return 'تصنيفات الألعاب لإنشاء الطاولة';
      case RoomsMenuMode.cards:
        return 'ألعاب الورق';
      case RoomsMenuMode.dice:
        return 'ألعاب النرد';
      case RoomsMenuMode.domino:
        return 'ألعاب الدومينو';
      case RoomsMenuMode.memory:
        return 'ألعاب الذاكرة والتركيز';
      case RoomsMenuMode.sports:
        return 'ألعاب رياضية';
    }
  }

  List<_RoomsMenuItem> get _currentItems {
    switch (_mode) {
      case RoomsMenuMode.main:
        return [
          _RoomsMenuItem(
            title: 'إنشاء',
            onTap: () {
              setState(() => _mode = RoomsMenuMode.categories);
              context.read<AccessibilityAnnouncer>().announce('تصنيفات الألعاب لإنشاء الطاولة');
            },
          ),
          _RoomsMenuItem(
            title: 'انضمام',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinRoomsScreen()),
              );
            },
          ),
        ];
      case RoomsMenuMode.categories:
        return [
          _RoomsMenuItem(
            title: 'ألعاب الكروت',
            onTap: () => setState(() => _mode = RoomsMenuMode.cards),
          ),
          _RoomsMenuItem(
            title: 'ألعاب النرد',
            onTap: () => setState(() => _mode = RoomsMenuMode.dice),
          ),
          _RoomsMenuItem(
            title: 'ألعاب الدومينو',
            onTap: () => setState(() => _mode = RoomsMenuMode.domino),
          ),
          _RoomsMenuItem(
            title: 'ألعاب الذاكرة',
            onTap: () => setState(() => _mode = RoomsMenuMode.memory),
          ),
          _RoomsMenuItem(
            title: 'ألعاب الرياضة',
            onTap: () => setState(() => _mode = RoomsMenuMode.sports),
          ),
        ];
      case RoomsMenuMode.cards:
        return [
          _RoomsMenuItem(
            title: 'أونو',
            onTap: () => _createGame('UNO', 'أونو'),
          ),
          _RoomsMenuItem(
            title: 'إسكوبا',
            onTap: () => _createGame('SCOPA', 'إسكوبا'),
          ),
          _RoomsMenuItem(
            title: 'تسعة وتسعون',
            onTap: () => _createGame('NINETY_NINE', 'تسعة وتسعون'),
          ),
        ];
      case RoomsMenuMode.dice:
        return [
          _RoomsMenuItem(
            title: 'فاركل',
            onTap: () => _createGame('FARKLE', 'فاركل'),
          ),
          _RoomsMenuItem(
            title: 'السلم والثعبان',
            onTap: () => _createGame('SNAKES_LADDERS', 'السلم والثعبان'),
          ),
        ];
      case RoomsMenuMode.domino:
        return [
          _RoomsMenuItem(
            title: 'دومينو',
            onTap: () => _createGame('DOMINO', 'دومينو'),
          ),
          _RoomsMenuItem(
            title: 'دومينو أمريكي',
            onTap: () => _createGame('AMERICAN_DOMINO', 'دومينو أمريكي'),
          ),
        ];
      case RoomsMenuMode.memory:
        return [
          _RoomsMenuItem(
            title: 'صيد اللص',
            onTap: () => _createGame('THIEF_HUNT', 'صيد اللص'),
          ),
        ];
      case RoomsMenuMode.sports:
        return [
          _RoomsMenuItem(
            title: 'تنس',
            onTap: () => _createGame('TENNIS', 'تنس'),
          ),
        ];
    }
  }

  bool _handleBack() {
    if (_mode == RoomsMenuMode.cards ||
        _mode == RoomsMenuMode.dice ||
        _mode == RoomsMenuMode.domino ||
        _mode == RoomsMenuMode.memory ||
        _mode == RoomsMenuMode.sports) {
      setState(() => _mode = RoomsMenuMode.categories);
      return false;
    } else if (_mode == RoomsMenuMode.categories) {
      setState(() => _mode = RoomsMenuMode.main);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _handleBack(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_handleBack()) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: ListView.separated(
            itemCount: _currentItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, index) {
              final item = _currentItems[index];
              return ListTile(
                title: Text(item.title),
                onTap: item.onTap,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomsMenuItem {
  final String title;
  final VoidCallback onTap;
  _RoomsMenuItem({required this.title, required this.onTap});
}
