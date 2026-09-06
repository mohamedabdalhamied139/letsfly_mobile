import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Representation of an individual UNO playing card.
class UnoCardModel extends Equatable {
  final String cardId;
  final String color; // 'red', 'blue', 'green', 'yellow', 'wild', etc.
  final String type; // 'number', 'skip', 'reverse', 'draw_two', 'wild', 'wild_draw_four', etc.
  final int? value; // 0-9 for numbers

  const UnoCardModel({
    required this.cardId,
    required this.color,
    required this.type,
    this.value,
  });

  bool get isWild =>
      color == 'wild' ||
      type == 'wild' ||
      type == 'wild_draw_four' ||
      type == 'wild_draw_two' ||
      type == 'wild_draw_six' ||
      type == 'wild_draw_ten' ||
      type == 'wild_reverse_draw_four' ||
      type == 'color_roulette' ||
      type == 'flip';

  factory UnoCardModel.fromJson(Map<String, dynamic> json) {
    return UnoCardModel(
      cardId: json['card_id'] as String? ?? json['id'] as String? ?? '',
      color: (json['color'] as String? ?? 'wild').toLowerCase(),
      type: (json['type'] as String? ?? 'number').toLowerCase(),
      value: json['value'] is int
          ? json['value'] as int
          : int.tryParse('${json['value']}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_id': cardId,
      'color': color,
      'type': type,
      'value': value,
    };
  }

  /// Returns localized accessible label for screen readers.
  String getLocalizedLabel(String langCode) {
    final isAr = langCode == 'ar';
    if (isAr) {
      return _getArabicLabel();
    } else {
      return _getEnglishLabel();
    }
  }

  String _getArabicLabel() {
    final colorMap = {
      'red': 'أحمر',
      'yellow': 'أصفر',
      'green': 'أخضر',
      'blue': 'أزرق',
      'orange': 'برتقالي',
      'pink': 'وردي',
      'purple': 'بنفسجي',
      'teal': 'تركوازي',
      'wild': 'حر',
    };
    final typeMap = {
      'skip': 'تخطي',
      'reverse': 'عكس الاتجاه',
      'draw_two': 'سحب 2',
      'wild': 'تبديل اللون',
      'wild_draw_four': 'تبديل اللون وسحب 4',
      'buzzer': 'جرس',
      'skip_everyone': 'تخطي الجميع',
      'discard_all': 'إسقاط الكل',
      'draw_one': 'سحب 1',
      'draw_five': 'سحب 5',
      'flip': 'قلب',
    };

    final colorAr = colorMap[color] ?? color;
    if (type == 'number') {
      return '$colorAr ${value ?? ''}';
    }
    final nameAr = typeMap[type] ?? type;
    if (isWild || color == 'wild') {
      return nameAr;
    }
    return '$colorAr $nameAr';
  }

  String _getEnglishLabel() {
    final colorMap = {
      'red': 'Red',
      'yellow': 'Yellow',
      'green': 'Green',
      'blue': 'Blue',
      'orange': 'Orange',
      'pink': 'Pink',
      'purple': 'Purple',
      'teal': 'Teal',
      'wild': 'Wild',
    };
    final typeMap = {
      'skip': 'Skip',
      'reverse': 'Reverse',
      'draw_two': 'Draw Two (+2)',
      'wild': 'Wild Color Change',
      'wild_draw_four': 'Wild Draw Four (+4)',
      'buzzer': 'Buzzer',
      'skip_everyone': 'Skip Everyone',
      'discard_all': 'Discard All',
      'draw_one': 'Draw One (+1)',
      'draw_five': 'Draw Five (+5)',
      'flip': 'Flip',
    };

    final colorEn = colorMap[color] ?? color;
    if (type == 'number') {
      return '$colorEn ${value ?? ''}';
    }
    final nameEn = typeMap[type] ?? type;
    if (isWild || color == 'wild') {
      return nameEn;
    }
    return '$colorEn $nameEn';
  }

  /// Get visual UI color for card rendering.
  Color getUiColor() {
    switch (color) {
      case 'red':
        return AppColors.unoRed;
      case 'blue':
        return AppColors.unoBlue;
      case 'green':
        return AppColors.unoGreen;
      case 'yellow':
        return AppColors.unoYellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pinkAccent;
      case 'teal':
        return Colors.teal;
      default:
        return const Color(0xFF2C3E50);
    }
  }

  /// Checks if this card is playable against top card and current active color.
  bool isPlayable(UnoCardModel? topCard, String currentColor) {
    if (isWild) return true;
    if (type == 'buzzer' || type == 'flip' || type == 'skip_everyone') return true;
    if (color == currentColor) return true;
    if (topCard != null && type == topCard.type) {
      if (type == 'number') {
        return value == topCard.value;
      }
      return true;
    }
    if (type == 'number' && topCard != null && topCard.type == 'number') {
      return value == topCard.value;
    }
    return false;
  }

  @override
  List<Object?> get props => [cardId, color, type, value];
}
