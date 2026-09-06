import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/social_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<Map<String,dynamic>> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<Map<String,dynamic>> _load() => context.read<SocialRepository>().blocked();
  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحظورون'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'تحديث')]),
      body: FutureBuilder<Map<String,dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل المحظورين: ${snapshot.error}'));
          final rows = snapshot.data?['blocked'] as List? ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا يوجد مستخدمون محظورون.'));
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final u = Map<String,dynamic>.from(rows[index] as Map);
              final id = (u['id'] as num?)?.toInt();
              return ListTile(
                title: Text('${u['display_name'] ?? u['username'] ?? ''}'),
                subtitle: Text('@${u['username'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open), tooltip: 'إلغاء الحظر',
                  onPressed: id == null ? null : () async { try { await context.read<SocialRepository>().unblock(id); _reload(); } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إلغاء الحظر: $e'))); } },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
