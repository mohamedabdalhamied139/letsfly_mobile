import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/social_repository.dart';
import 'profile_screen.dart';
import '../../bloc/room_cubit.dart';
import '../rooms/room_lobby_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<Map<String, dynamic>> _load() => context.read<SocialRepository>().friends();
  void _reload() => setState(() => _future = _load());

  Future<void> _search() async {
    final c = TextEditingController();
    try {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('البحث عن مستخدم'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () async {
            final q = c.text.trim();
            if (q.isEmpty) return;
            try {
              final d = await context.read<SocialRepository>().search(q);
              if (!mounted) return;
              Navigator.pop(ctx);
              final raw = d['users'] as List? ?? const [];
              await _showUsers(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
            } catch (e) {
              if (ctx.mounted) Navigator.pop(ctx);
              _snack('فشل البحث: $e');
            }
          }, child: const Text('بحث')),
        ],
      ));
    } finally { c.dispose(); }
  }

  Future<void> _showUsers(List<Map<String, dynamic>> users) async {
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('نتائج البحث'),
      content: SizedBox(width: 420, height: 360, child: ListView(children: [
        for (final u in users) ListTile(
          title: Text('${u['display_name'] ?? u['username'] ?? 'مستخدم'}'),
          subtitle: Text('@${u['username'] ?? ''}'),
          trailing: IconButton(
            tooltip: 'إرسال طلب صداقة', icon: const Icon(Icons.person_add),
            onPressed: () async {
              try { await context.read<SocialRepository>().sendFriendRequest((u['id'] as num).toInt()); if (ctx.mounted) Navigator.pop(ctx); _reload(); }
              catch (e) { _snack('تعذر إرسال الطلب: $e'); }
            },
          ),
        ),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _actions(Map<String, dynamic> u) async {
    final id = (u['id'] as num?)?.toInt();
    if (id == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        ListTile(title: Text('${u['display_name'] ?? u['username'] ?? 'مستخدم'}'), subtitle: Text('@${u['username'] ?? ''}'), enabled: false),
        _action(ctx, 'profile', 'الملف الشخصي', Icons.person),
        _action(ctx, 'message', 'إرسال رسالة', Icons.mail),
        _action(ctx, 'h2h', 'إحصائيات المواجهات', Icons.bar_chart),
        _action(ctx, 'mute', 'كتم الإشعارات', Icons.notifications_off),
        _action(ctx, 'gift', 'إرسال هدية', Icons.card_giftcard),
        _action(ctx, 'invite', 'دعوة إلى طاولتي', Icons.meeting_room),
        _action(ctx, 'challenge', 'تحدي في لعبة جديدة', Icons.sports_esports),
        _action(ctx, 'unfriend', 'إلغاء الصداقة', Icons.person_remove),
        _action(ctx, 'block', 'حظر', Icons.block),
      ])),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'profile':
          final d = await context.read<SocialRepository>().profile(id);
          if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: id, initialData: d)));
          break;
        case 'message': await _message(id, '${u['display_name'] ?? u['username'] ?? ''}'); break;
        case 'h2h':
          final d = await context.read<SocialRepository>().headToHead(id);
          if (mounted) _info('أنت ضده', 'إجمالي المباريات: ${d['total_played'] ?? 0}\nفوزك: ${d['you_wins'] ?? 0}\nفوزه: ${d['other_wins'] ?? 0}');
          break;
        case 'mute':
          final f = await context.read<SocialRepository>().getMutes(id);
          if (mounted) await _mute(id, f);
          break;
        case 'gift': await _gift(id); break;
        case 'invite':
          final rs = context.read<RoomCubit>().state;
          if (rs is! RoomActive) throw Exception('يجب أن تكون داخل طاولة لإرسال الدعوة.');
          await context.read<SocialRepository>().inviteToRoom(id, rs.room.roomId);
          break;
        case 'challenge':
          final game = await _chooseGame();
          if (game != null) { final result = await context.read<SocialRepository>().challenge(id, game); final roomId = result['room_id']?.toString(); if (roomId != null && roomId.isNotEmpty && mounted) { context.read<RoomCubit>().enterRoom(roomId); await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomLobbyScreen())); } }
          break;
        case 'unfriend': await context.read<SocialRepository>().unfriend(id); break;
        case 'block': await context.read<SocialRepository>().block(id); break;
      }
      _reload();
    } catch (e) { _snack('تعذر تنفيذ العملية: $e'); }
  }

  Widget _action(BuildContext c, String value, String text, IconData icon) => ListTile(leading: Icon(icon), title: Text(text), onTap: () => Navigator.pop(c, value));

  Future<void> _message(int id, String name) async {
    final c = TextEditingController();
    try {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('إرسال رسالة إلى $name'), content: TextField(controller: c, maxLines: 5, decoration: const InputDecoration(labelText: 'الرسالة')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { if (c.text.trim().isEmpty) return; try { await context.read<SocialRepository>().message(id, c.text.trim()); if (ctx.mounted) Navigator.pop(ctx); } catch (e) { _snack('فشل الإرسال: $e'); } }, child: const Text('إرسال'))],
      ));
    } finally { c.dispose(); }
  }

  Future<void> _gift(int id) async {
    final c = TextEditingController(text: '1');
    try {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('إرسال هدية'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد العملات')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { final n = int.tryParse(c.text.trim()); if (n == null || n <= 0) return; try { await context.read<SocialRepository>().gift(id, n); if (ctx.mounted) Navigator.pop(ctx); } catch (e) { _snack('فشل إرسال الهدية: $e'); } }, child: const Text('إرسال'))],
      ));
    } finally { c.dispose(); }
  }

  Future<void> _mute(int id, Map<String, dynamic> flags) async {
    final values = <String, bool>{'all': flags['all'] == true, 'private_messages': flags['private_messages'] == true, 'invitations': flags['invitations'] == true, 'presence': flags['presence'] == true};
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('كتم الإشعارات'),
      content: StatefulBuilder(builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final k in values.keys) SwitchListTile(title: Text(k), value: values[k]!, onChanged: (v) => set(() => values[k] = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), ElevatedButton(onPressed: () async { await context.read<SocialRepository>().setMutes(id, values); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('حفظ'))],
    ));
  }


  Future<String?> _chooseGame() async {
    return showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('اختار اللعبة'),
      children: [for (final g in const ['UNO','NINETY_NINE','THIEF_HUNT','FARKLE','DOMINO','AMERICAN_DOMINO','SCOPA','SNAKES_LADDERS','TENNIS']) SimpleDialogOption(onPressed: () => Navigator.pop(ctx,g), child: Text(g))],
    ));
  }

  void _info(String title, String body) => showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))]));
  void _snack(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأصدقاء'), actions: [IconButton(onPressed: _search, icon: const Icon(Icons.search), tooltip: 'بحث'), IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'تحديث')]),
    body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (c, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Text('تعذر تحميل الأصدقاء: ${s.error}'));
      final d = s.data ?? {}; final friends = d['friends'] as List? ?? const []; final incoming = d['requests'] as List? ?? const []; final sent = d['sent'] as List? ?? const [];
      return ListView(padding: const EdgeInsets.all(12), children: [
        if (incoming.isNotEmpty) const Text('طلبات الصداقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        for (final raw in incoming) _request(Map<String, dynamic>.from(raw as Map), true),
        const SizedBox(height: 8), const Text('أصدقاؤك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (friends.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد أصدقاء حتى الآن')),
        for (final raw in friends) _friend(Map<String, dynamic>.from(raw as Map)),
        if (sent.isNotEmpty) const Text('طلبات أرسلتها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        for (final raw in sent) _request(Map<String, dynamic>.from(raw as Map), false),
      ]);
    }),
  );

  Widget _request(Map<String, dynamic> u, bool incoming) { final rid = (u['request_id'] as num?)?.toInt(); return ListTile(title: Text('${u['display_name'] ?? u['username'] ?? ''}'), subtitle: Text('@${u['username'] ?? ''}'), trailing: Wrap(children: [if (incoming && rid != null) IconButton(onPressed: () async { await context.read<SocialRepository>().acceptFriendRequest(rid); _reload(); }, icon: const Icon(Icons.check), tooltip: 'قبول'), if (rid != null) IconButton(onPressed: () async { if (incoming) await context.read<SocialRepository>().rejectFriendRequest(rid); else await context.read<SocialRepository>().cancelFriendRequest(rid); _reload(); }, icon: const Icon(Icons.close), tooltip: incoming ? 'رفض' : 'إلغاء')])); }
  Widget _friend(Map<String, dynamic> u) => ListTile(onTap: () => _actions(u), leading: Icon(Icons.circle, size: 14, color: u['online'] == true ? Colors.green : Colors.grey), title: Text('${u['display_name'] ?? u['username'] ?? ''}'), subtitle: Text('@${u['username'] ?? ''}'), trailing: const Icon(Icons.more_vert));
}
