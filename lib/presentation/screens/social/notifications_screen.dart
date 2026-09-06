import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../bloc/room_cubit.dart';
import '../rooms/room_lobby_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String,dynamic>> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<Map<String,dynamic>> _load() => context.read<SocialRepository>().notifications();
  void _reload() => setState(() => _future = _load());

  Future<void> _handle(Map<String,dynamic> n, bool accept) async {
    final payload = n['payload'];
    final id = payload is Map ? (payload['invitation_id'] as num?)?.toInt() : null;
    if (id == null) return;
    try {
      if (accept) {
        final result = await context.read<SocialRepository>().acceptInvitation(id);
        final roomId = result['room_id']?.toString();
        if (roomId != null && roomId.isNotEmpty && mounted) {
          await context.read<RoomCubit>().enterRoom(roomId);
          if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomLobbyScreen()));
        }
      } else {
        await context.read<SocialRepository>().rejectInvitation(id);
      }
      if (mounted) _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تنفيذ الدعوة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'تحديث')]),
      body: FutureBuilder<Map<String,dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل الإشعارات: ${snapshot.error}'));
          final rows = snapshot.data?['notifications'] as List? ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا توجد إشعارات جديدة'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final n = Map<String,dynamic>.from(rows[index] as Map);
              final type = '${n['event_type'] ?? ''}';
              final invite = type == 'CHALLENGE_INVITATION' && n['payload'] is Map;
              final id = (n['id'] as num?)?.toInt();
              return Card(
                child: ListTile(
                  onTap: id == null ? null : () async { try { await context.read<ActivityRepository>().markRead(eventId: id); _reload(); } catch (_) {} },
                  title: Text('${n['text'] ?? ''}'),
                  subtitle: Text('${n['created_at'] ?? ''}'),
                  isThreeLine: true,
                  trailing: invite ? Wrap(children: [
                    IconButton(onPressed: () => _handle(n, true), icon: const Icon(Icons.check), tooltip: 'قبول'),
                    IconButton(onPressed: () => _handle(n, false), icon: const Icon(Icons.close), tooltip: 'رفض'),
                  ]) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
