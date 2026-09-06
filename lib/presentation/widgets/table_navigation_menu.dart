import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/accessibility/accessibility_announcer.dart';
import '../bloc/room_cubit.dart';

enum TableNavAction {
  players,
  scores,
  turn,
  rules,
  chat,
}

Future<TableNavAction?> showTableNavigationMenu(
  BuildContext context, {
  required String game,
}) async {
  final items = <({TableNavAction action, String label})>[
    (action: TableNavAction.players, label: 'اللاعبون على الطاولة'),
    (action: TableNavAction.scores, label: 'النتائج والهدف'),
    (action: TableNavAction.turn, label: 'الدور الحالي'),
    (action: TableNavAction.rules, label: 'قواعد اللعبة الحالية'),
    (action: TableNavAction.chat, label: 'سجل النشاط والدردشة'),
  ];

  return showDialog<TableNavAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('قائمة التنقل'),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              title: Text(item.label),
              onTap: () => Navigator.of(dialogContext).pop(item.action),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> executeTableNavAction(
  BuildContext context,
  TableNavAction action, {
  VoidCallback? onOpenChat,
}) async {
  final roomState = context.read<RoomCubit>().state;
  final announcer = context.read<AccessibilityAnnouncer>();

  if (roomState is! RoomActive) {
    announcer.announce('لست داخل طاولة حالياً.');
    return;
  }

  final room = roomState.room;

  switch (action) {
    case TableNavAction.players:
      final count = room.players.length;
      if (count == 0) {
        announcer.announce('لا يوجد لاعبون على الطاولة.');
      } else {
        final names = room.players.map((id) => room.playerNames[id] ?? 'لاعب').toList();
        final namesStr = names.join(' و ');
        final String text;
        if (count == 1) {
          text = 'لاعب واحد على الطاولة: ${names[0]}';
        } else if (count == 2) {
          text = 'لاعبان على الطاولة: ${names[0]} و ${names[1]}';
        } else if (count >= 3 && count <= 10) {
          text = '$count لاعبين على الطاولة: $namesStr';
        } else {
          text = '$count لاعباً على الطاولة: $namesStr';
        }
        announcer.announce(text);
      }
      break;

    case TableNavAction.scores:
      final target = room.targetScore;
      if (room.scores.isEmpty) {
        announcer.announce(target != null ? 'عدد النقاط النهائي $target' : 'لا توجد نقاط بعد.');
      } else {
        final parts = <String>[];
        room.scores.forEach((key, val) {
          final n = room.playerNames[key] ?? 'لاعب';
          parts.add('$n $val');
        });
        if (target != null) {
          parts.add('عدد النقاط النهائي $target');
        }
        announcer.announce(parts.join('، '));
      }
      break;

    case TableNavAction.turn:
      if (!room.isPlaying()) {
        announcer.announce('المباراة لم تبدأ بعد.');
      } else {
        final hostId = room.hostId;
        final name = room.playerNames[hostId] ?? '';
        announcer.announce(name.isNotEmpty ? 'دور $name' : 'غير محدد');
      }
      break;

    case TableNavAction.rules:
      final rules = room.rules;
      final game = (room.game ?? '').toUpperCase();
      if (rules.isEmpty) {
        announcer.announce('اللعب بالوضع الافتراضي.');
      } else {
        final activeRules = <String>[];
        if (game == 'UNO') {
          const ruleLabels = {
            'draw_to_match': 'سحب حتى المطابقة',
            'jump_in': 'المقاطعة (القفز للعب)',
            'force_play': 'إلزام اللعب',
            'stack_draw_two': 'مضاعفة اسحب 2',
            'stack_draw_four': 'مضاعفة اسحب 4',
            'seven_zero': 'قاعدة 7 و 0',
            'wild_draw_four_bluff': 'الاعتراض على اسحب 4',
            'pass_on_draw': 'التمرير بعد السحب',
          };
          rules.forEach((k, enabled) {
            if (enabled == true) {
              activeRules.add(ruleLabels[k] ?? k.toString());
            }
          });
        } else if (game == 'SCOPA') {
          final modeMap = {
            'classic': 'سكوبا الكلاسيكية',
            'escoba_15': 'إسكوبا 15',
            'asso_piglia_tutto': 'آسو بيجليا توتو',
            'scopone': 'سكوبون',
            'inverted': 'سكوبا المعكوسة',
          };
          if (rules['scopa_mode'] != null) {
            activeRules.add(modeMap[rules['scopa_mode']] ?? rules['scopa_mode'].toString());
          }
          if (rules['asso_piglia_tutto'] == true && !activeRules.contains('آسو بيجليا توتو')) {
            activeRules.add('آسو بيجليا توتو');
          }
          if (rules['scopone'] == true && !activeRules.contains('سكوبون')) {
            activeRules.add('سكوبون');
          }
          if (rules['inverted'] == true && !activeRules.contains('سكوبا المعكوسة')) {
            activeRules.add('سكوبا المعكوسة');
          }
        } else if (game == 'SNAKES_LADDERS') {
          if (rules['knockout'] == true) activeRules.add('نظام استبعاد اللاعبين');
          if (rules['mystery_tiles'] == true) activeRules.add('المربعات الغامضة');
        } else if (game == 'THIEF_HUNT') {
          activeRules.add('عدد الجولات: ${rules['rounds'] ?? 5}');
          if (rules['allow_human_thief'] == true) activeRules.add('السماح للاعبين بدور اللص');
          if (rules['elimination_mode'] == true) activeRules.add('نظام الإقصاء');
        } else if (game == 'DOMINO' || game == 'AMERICAN_DOMINO') {
          final mode = rules['mode'] ?? 'draw';
          activeRules.add(mode == 'block' ? 'لعب بدون سحب' : (mode == 'all_fives' ? 'خمسات' : 'لعب مع سحب'));
          if (rules['count_remaining_pips'] == true) activeRules.add('حساب نقاط الخصوم');
        } else if (game == 'FARKLE') {
          activeRules.add('الحد الأدنى للإيداع: ${rules['min_bank'] ?? 30}');
          activeRules.add('الحد الأدنى لفتح الرصيد: ${rules['first_bank_min'] ?? 50}');
        } else if (game == 'TENNIS') {
          final diffNames = {'EASY': 'سهل', 'NORMAL': 'متوسط', 'HARD': 'صعب', 'EXPERT': 'محترف'};
          final diff = rules['bot_difficulty'] ?? 'NORMAL';
          activeRules.add('صعوبة البوت: ${diffNames[diff] ?? diff}');
          final target = room.targetScore ?? 1;
          activeRules.add('عدد المجموعات للفوز: $target');
        } else {
          rules.forEach((k, v) {
            if (v == true) {
              activeRules.add(k.toString());
            } else if (v is! bool && v != null) {
              activeRules.add('$k: $v');
            }
          });
        }

        if (activeRules.isEmpty) {
          announcer.announce('اللعب بالوضع الافتراضي.');
        } else {
          announcer.announce('الإعدادات الحالية: ${activeRules.join("، ")}');
        }
      }
      break;

    case TableNavAction.chat:
      if (onOpenChat != null) {
        onOpenChat();
      } else {
        announcer.announce('افتح سجل النشاط من الشاشة.');
      }
      break;
  }
}
