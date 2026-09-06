import 'package:equatable/equatable.dart';

class NinetyNineCardModel extends Equatable {
  final String cardId;
  final String suit;
  final int value;

  const NinetyNineCardModel({
    required this.cardId,
    required this.suit,
    required this.value,
  });

  factory NinetyNineCardModel.fromJson(Map<String, dynamic> json) {
    return NinetyNineCardModel(
      cardId: json['id'] as String? ?? '',
      suit: json['suit'] as String? ?? '',
      value: json['value'] as int? ?? 0,
    );
  }

  String getLocalizedLabel(String lang) {
    String rankAr = _getRankAr(value);
    String suitAr = _getSuitAr(suit);
    return '$rankAr من $suitAr';
  }

  String _getRankAr(int val) {
    switch (val) {
      case 1: return 'آس';
      case 11: return 'جاك';
      case 12: return 'كوين';
      case 13: return 'ملك';
      default: return val.toString();
    }
  }

  String _getSuitAr(String s) {
    switch (s.toLowerCase()) {
      case 'diamonds': return 'ديناري';
      case 'hearts': return 'قلب';
      case 'spades': return 'بستوني';
      case 'clubs': return 'شجرة';
      default: return s;
    }
  }

  @override
  List<Object?> get props => [cardId, suit, value];
}
