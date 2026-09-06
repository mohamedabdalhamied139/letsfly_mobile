import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../bloc/auth_bloc.dart';
import '../../../data/repositories/social_repository.dart';
import '../rooms/rooms_menu_screen.dart';
import '../settings/settings_screen.dart';
import '../social/friends_screen.dart';
import '../social/online_users_screen.dart';
import '../social/profile_screen.dart';
import '../social/notifications_screen.dart';
import '../../../core/services/app_update_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _onlineCount = 0;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _fetchOnlineCount();
    _onlineTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchOnlineCount());
    // Check for updates on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateManager.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnlineCount() async {
    try {
      final res = await context.read<SocialRepository>().onlineUsers();
      final users = res['users'] as List? ?? [];
      if (mounted) {
        setState(() {
          _onlineCount = users.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _showFeedback(BuildContext context) async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحدث معنا'),
        content: TextField(
          controller: c,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'اكتب رسالتك'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = c.text.trim();
              if (text.isEmpty) return;
              try {
                await context.read<SocialRepository>().feedback(text);
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Exact 8 items from Windows client home_view.py:
    // 1. الطاولات (rooms)
    // 2. الأصدقاء (friends)
    // 3. المتصلون (X) (online)
    // 4. ملفي الشخصي (my_profile)
    // 5. الإعدادات (settings)
    // 6. الإشعارات (notifications)
    // 7. تحدث معنا (contact)
    // 8. تسجيل الخروج (logout)
    final menuItems = [
      _MenuItem(
        title: 'الطاولات',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RoomsMenuScreen()),
          );
        },
      ),
      _MenuItem(
        title: 'الأصدقاء',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsScreen()),
          );
        },
      ),
      _MenuItem(
        title: 'المتصلون ()',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OnlineUsersScreen()),
          );
        },
      ),
      _MenuItem(
        title: 'ملفي الشخصي',
        action: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
      ),
      _MenuItem(
        title: 'الإعدادات',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      _MenuItem(
        title: 'الإشعارات',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
      _MenuItem(
        title: 'تحدث معنا',
        action: () => _showFeedback(context),
      ),
      _MenuItem(
        title: 'تسجيل الخروج',
        textColor: AppColors.error,
        action: () {
          context.read<AuthBloc>().add(LogoutRequested());
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('القائمة الرئيسية'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.separated(
          itemCount: menuItems.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.surface),
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return ListTile(
              title: Text(
                item.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: item.textColor,
                ),
              ),
              onTap: item.action,
            );
          },
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final Color? textColor;
  final VoidCallback action;

  _MenuItem({
    required this.title,
    this.textColor,
    required this.action,
  });
}
