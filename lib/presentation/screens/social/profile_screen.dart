import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/social_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../bloc/auth_bloc.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;
  final Map<String, dynamic>? initialData;
  const ProfileScreen({super.key, this.userId, this.initialData});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get _isMine => widget.userId == null;

  Future<void> _edit() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) return;
    final user = auth.user;
    final name = TextEditingController(text: user.displayName);
    final bio = TextEditingController(text: user.bio);
    var gender = user.gender;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تعديل الملف الشخصي'),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: bio, decoration: const InputDecoration(labelText: 'البايو')),
              DropdownButtonFormField<String>(
                value: gender.isEmpty ? null : gender,
                items: const [
                  DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                  DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                ],
                onChanged: (v) { if (v != null) gender = v; },
                decoration: const InputDecoration(labelText: 'الجنس'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<SocialRepository>().updateProfile(
                    displayName: name.text.trim(), gender: gender, bio: bio.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) context.read<AuthBloc>().add(AuthCheckRequested());
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally { name.dispose(); bio.dispose(); }
  }

  Future<void> _password() async {
    final old = TextEditingController();
    final neu = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: old, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            TextField(controller: neu, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<AuthRepository>().changePassword(currentPassword: old.text, newPassword: neu.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل تغيير كلمة المرور: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally { old.dispose(); neu.dispose(); }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('سيتم حذف الحساب وبياناته نهائيًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<SocialRepository>().deleteAccount();
      if (mounted) context.read<AuthBloc>().add(LogoutRequested());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حذف الحساب: $e')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isMine ? 'ملفي الشخصي' : 'الملف الشخصي'),
      actions: [if (_isMine) IconButton(tooltip: 'تعديل', onPressed: _edit, icon: const Icon(Icons.edit))],
    ),
    body: _isMine ? _myBody() : _otherBody(),
  );

  Widget _myBody() {
    final auth = context.watch<AuthBloc>().state;
    final u = auth is Authenticated ? auth.user : null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.person, color: AppColors.primary), title: Text(u?.displayName ?? 'اللاعب'), subtitle: Text('@${u?.username ?? ''}'))),
      Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('الرصيد'), subtitle: Text('${u?.coins ?? 0} عملة'))),
      if ((u?.gender ?? '').isNotEmpty) Card(child: ListTile(title: const Text('الجنس'), subtitle: Text(u!.gender))),
      if ((u?.bio ?? '').isNotEmpty) Card(child: ListTile(title: const Text('البايو'), subtitle: Text(u!.bio))),
      ListTile(leading: const Icon(Icons.password), title: const Text('تغيير كلمة المرور'), onTap: _password),
      ListTile(leading: const Icon(Icons.delete_forever), title: const Text('حذف الحساب'), onTap: _delete),
    ]);
  }

  Widget _otherBody() {
    final d = widget.initialData ?? const <String, dynamic>{};
    final stats = d['stats'] as List? ?? const [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(title: Text('${d['display_name'] ?? d['username'] ?? ''}'), subtitle: Text('@${d['username'] ?? ''}'), leading: Icon(Icons.circle, color: d['online'] == true ? Colors.green : Colors.grey))),
      Card(child: ListTile(title: const Text('البايو'), subtitle: Text('${d['bio'] ?? 'لا يوجد بايو'}'))),
      const Text('الإحصائيات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      for (final raw in stats) if (raw is Map) ListTile(title: Text('${raw['game_name'] ?? 'لعبة'}'), subtitle: Text('لعب ${raw['played'] ?? 0} — فوز ${raw['wins'] ?? 0} — خسارة ${raw['losses'] ?? 0} — تصنيف ${raw['rating'] ?? 1000}')),
    ]);
  }
}
