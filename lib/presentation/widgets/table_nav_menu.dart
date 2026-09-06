import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/room_cubit.dart';
import '../bloc/auth_bloc.dart';
import '../../data/repositories/room_ws_service.dart';
import '../../core/constants/app_colors.dart';
import '../screens/social/friends_screen.dart';
import '../screens/social/online_users_screen.dart';
import '../screens/social/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/social/notifications_screen.dart';
import '../../../data/repositories/social_repository.dart';

/// Navigation and connection actions available across the entire app from inside a table
enum TableNavAction {
  reconnect,
  navFriends,
  navOnlineUsers,
  navProfile,
  navSettings,
  navNotifications,
  navFeedback,
  exitLetsFly,
}

Future<TableNavAction?> showTableNavMenu(BuildContext context) async {
  final roomWs = context.read<RoomWsService>();
  final latency = roomWs.latencyMs;

  return showModalBottomSheet<TableNavAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with latency
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'قائمة التنقل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'زمن الاستجابة: ${latency > 0 ? latency : '--'} مللي ثانية',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.unoGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Connection control
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.primary),
                title: const Text('إعادة الاتصال بالسيرفر'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.reconnect),
              ),

              const Divider(),

              // Navigation destinations
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('الأصدقاء'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navFriends),
              ),
              ListTile(
                leading: const Icon(Icons.circle, color: Colors.green),
                title: const Text('المتصلون'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navOnlineUsers),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('ملفي الشخصي'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navProfile),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('الإعدادات'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navSettings),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('الإشعارات'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navNotifications),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('تحدث معنا'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.navFeedback),
              ),

              const Divider(),

              // Clean full disconnect & logout
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('الخروج من Let\'s Fly'),
                onTap: () => Navigator.of(sheetCtx).pop(TableNavAction.exitLetsFly),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> executeTableNavAction(
  BuildContext context,
  TableNavAction action,
) async {
  final room = context.read<RoomCubit>();
  switch (action) {
    case TableNavAction.reconnect:
      await context.read<RoomWsService>().reconnect();
      break;
    case TableNavAction.navFriends:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
      break;
    case TableNavAction.navOnlineUsers:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineUsersScreen()));
      break;
    case TableNavAction.navProfile:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      break;
    case TableNavAction.navSettings:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      break;
    case TableNavAction.navNotifications:
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      break;
    case TableNavAction.navFeedback:
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
      break;
    case TableNavAction.exitLetsFly:
      await room.leaveRoom();
      if (context.mounted) {
        context.read<AuthBloc>().add(LogoutRequested());
      }
      break;
  }
}
