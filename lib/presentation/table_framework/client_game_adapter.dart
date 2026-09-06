/// Mobile counterpart of the Windows ClientGameAdapter.
/// The adapter owns only game-specific presentation/actions; room lifecycle,
/// transport, chat, activity and table options stay in the shared table shell.
class ClientGameAdapter {
  final String gameId;
  final String titleAr;
  final String titleEn;
  final int defaultTargetScore;
  final Map<String, dynamic> defaultRules;
  final List<GameActionDefinition> actions;

  const ClientGameAdapter({
    required this.gameId,
    required this.titleAr,
    required this.titleEn,
    required this.defaultTargetScore,
    this.defaultRules = const {},
    this.actions = const [],
  });

  String title(String languageCode) => languageCode == 'en' ? titleEn : titleAr;
}

class GameActionDefinition {
  final String id;
  final String labelAr;
  final String labelEn;
  const GameActionDefinition(this.id, this.labelAr, this.labelEn);
  String label(String languageCode) => languageCode == 'en' ? labelEn : labelAr;
}

/// Single canonical registry matching the Windows/server game registry.
class ClientGameRegistry {
  ClientGameRegistry._();

  static const games = <String, ClientGameAdapter>{
    'UNO': ClientGameAdapter(gameId: 'UNO', titleAr: 'أونو', titleEn: 'UNO', defaultTargetScore: 500, defaultRules: {'responses': false, 'straights': false, 'interceptions': false, 'super_interceptions': false, 'bluff': false, 'skip_after_draw': false, 'zero_seven': false, 'buzzer': false, 'advanced_responses': false, 'draw_until_playable': false, 'eliminate_too_many': false, 'no_mercy': false, 'skip_everyone': false, 'discard_all': false, 'wild_draw_six_ten': false, 'wild_reverse_draw_four': false, 'color_roulette': false, 'uno_flip': false}),
    'NINETY_NINE': ClientGameAdapter(gameId: 'NINETY_NINE', titleAr: 'تسعة وتسعون', titleEn: 'Ninety-Nine', defaultTargetScore: 11, defaultRules: {'starting_tokens': 11}),
    'THIEF_HUNT': ClientGameAdapter(gameId: 'THIEF_HUNT', titleAr: 'مطاردة اللص', titleEn: 'Thief Hunt', defaultTargetScore: 1, defaultRules: {'rounds': 5, 'allow_human_thief': false, 'elimination_mode': false}),
    'FARKLE': ClientGameAdapter(gameId: 'FARKLE', titleAr: 'فاركل', titleEn: 'Farkle', defaultTargetScore: 1500, defaultRules: {'min_bank': 30, 'first_bank_min': 50}),
    'DOMINO': ClientGameAdapter(gameId: 'DOMINO', titleAr: 'دومينو كلاسيك', titleEn: 'Classic Domino', defaultTargetScore: 100, defaultRules: {'mode': 'draw', 'hand_size': 7}),
    'AMERICAN_DOMINO': ClientGameAdapter(gameId: 'AMERICAN_DOMINO', titleAr: 'دومينو أمريكاني', titleEn: 'American Domino', defaultTargetScore: 150, defaultRules: {'hand_size': 7, 'scoring_mode': 'standard'}),
    'SNAKES_LADDERS': ClientGameAdapter(gameId: 'SNAKES_LADDERS', titleAr: 'السلم والثعبان', titleEn: 'Snakes and Ladders', defaultTargetScore: 100, defaultRules: {'knockout': false, 'mystery_tiles': false}),
    'SCOPA': ClientGameAdapter(gameId: 'SCOPA', titleAr: 'إسكوبا', titleEn: 'Scopa', defaultTargetScore: 11, defaultRules: {'scopa_mode': 'classic', 'classic': true, 'escoba_15': false, 'asso_piglia_tutto': false, 'scopone': false, 'inverted': false}),
    'TENNIS': ClientGameAdapter(gameId: 'TENNIS', titleAr: 'تنس', titleEn: 'Tennis', defaultTargetScore: 1, defaultRules: {'bot_difficulty': 'NORMAL'}, actions: [
      GameActionDefinition('position:-1', 'الممر الأيسر', 'Left lane'),
      GameActionDefinition('position:1', 'الممر الأيمن', 'Right lane'),
      GameActionDefinition('serve', 'الإرسال', 'Serve'),
    ]),
  };

  static ClientGameAdapter get(String gameId) => games[gameId.toUpperCase()] ?? games['UNO']!;
  static bool contains(String gameId) => games.containsKey(gameId.toUpperCase());
}
