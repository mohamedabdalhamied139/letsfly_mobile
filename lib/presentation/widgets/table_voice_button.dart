import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../bloc/room_cubit.dart';

class TableVoiceButton extends StatelessWidget {
  const TableVoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    final roomState = context.watch<RoomCubit>().state;
    if (roomState is! RoomActive) return const SizedBox.shrink();

    final roomCubit = context.read<RoomCubit>();
    final voice = roomCubit.voiceService;
    final announcer = context.read<AccessibilityAnnouncer>();

    final String label;
    final String tooltip;
    final IconData icon;
    final Color color;

    if (!voice.sessionActive) {
      label = 'انضمام للمحادثة الصوتية';
      tooltip = 'اضغط للانضمام للمحادثة الصوتية';
      icon = Icons.mic_off;
      color = Colors.grey;
    } else if (voice.muted) {
      label = 'إلغاء كتم الميكروفون (الميكروفون مكتوم حالياً، اضغط مطولاً للخروج)';
      tooltip = 'الميكروفون مكتوم. اضغط لإلغاء الكتم، واضغط مطولاً للخروج من المحادثة';
      icon = Icons.mic_off;
      color = Colors.orange;
    } else {
      label = 'كتم الميكروفون (الميكروفون مفتوح حالياً، اضغط مطولاً للخروج)';
      tooltip = 'الميكروفون مفتوح. اضغط للكتم، واضغط مطولاً للخروج من المحادثة';
      icon = Icons.mic;
      color = Colors.green;
    }

    return Semantics(
      button: true,
      label: label,
      tooltip: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            if (!voice.sessionActive) {
              announcer.announce('جاري الانضمام للمحادثة الصوتية...');
              final success = await roomCubit.toggleVoiceSession();
              if (success) {
                announcer.announce('تم الانضمام للمحادثة الصوتية، الميكروفون مكتوم. اضغط لإلغاء الكتم');
              } else {
                announcer.announce('فشل الانضمام للمحادثة الصوتية');
              }
            } else {
              final unmuted = await roomCubit.toggleVoiceMute();
              announcer.announce(unmuted ? 'تم فتح الميكروفون' : 'تم كتم الميكروفون');
            }
          },
          onLongPress: () async {
            if (voice.sessionActive) {
              announcer.announce('جاري مغادرة المحادثة الصوتية...');
              await roomCubit.toggleVoiceSession();
              announcer.announce('تم الخروج من المحادثة الصوتية');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
