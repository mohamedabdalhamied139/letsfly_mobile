/// E2E Test Fixtures for Let's Fly Mobile Client
/// Authoritative test objects matching server protocol and Shared Table Architecture.
library letsfly_e2e_fixtures;

import 'dart:convert';

class TestUser {
  final int id;
  final String username;
  final String displayName;
  final String email;
  final int coins;
  final int tokenVersion;
  final String token;

  const TestUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    this.coins = 1000,
    this.tokenVersion = 0,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'email': email,
    'coins': coins,
    'token_version': tokenVersion,
  };
}

class TestFixtures {
  static const TestUser userAlice = TestUser(
    id: 1,
    username: 'alice',
    displayName: 'Alice Mobile',
    email: 'alice@letsfly.test',
    coins: 1250,
    tokenVersion: 1,
    token: 'mock_jwt_token_alice_ver1',
  );

  static const TestUser userBob = TestUser(
    id: 2,
    username: 'bob',
    displayName: 'Bob Desktop',
    email: 'bob@letsfly.test',
    coins: 900,
    tokenVersion: 1,
    token: 'mock_jwt_token_bob_ver1',
  );

  static const TestUser userCharlie = TestUser(
    id: 3,
    username: 'charlie',
    displayName: 'Charlie Bot',
    email: 'charlie@letsfly.test',
    coins: 1000,
    tokenVersion: 1,
    token: 'mock_jwt_token_charlie_ver1',
  );

  // Canonical cards
  static Map<String, dynamic> createCard({
    required String id,
    required String type,
    required String color,
    int? value,
    required String nameAr,
  }) {
    return {
      'id': id,
      'type': type,
      'color': color,
      'value': value,
      'name': nameAr,
    };
  }

  static final Map<String, dynamic> cardRed7 = createCard(
    id: 'c_red_7',
    type: 'number',
    color: 'red',
    value: 7,
    nameAr: 'أحمر 7',
  );

  static final Map<String, dynamic> cardRedSkip = createCard(
    id: 'c_red_skip',
    type: 'skip',
    color: 'red',
    value: null,
    nameAr: 'أحمر تخطي',
  );

  static final Map<String, dynamic> cardBlueReverse = createCard(
    id: 'c_blue_rev',
    type: 'reverse',
    color: 'blue',
    value: null,
    nameAr: 'أزرق عكس',
  );

  static final Map<String, dynamic> cardGreenDrawTwo = createCard(
    id: 'c_green_d2',
    type: 'draw_two',
    color: 'green',
    value: null,
    nameAr: 'أخضر اسحب 2',
  );

  static final Map<String, dynamic> cardWild = createCard(
    id: 'c_wild',
    type: 'wild',
    color: 'wild',
    value: null,
    nameAr: 'تغيير اللون',
  );

  static final Map<String, dynamic> cardWildDrawFour = createCard(
    id: 'c_wild_d4',
    type: 'wild_draw_four',
    color: 'wild',
    value: null,
    nameAr: 'تغيير اللون واسحب 4',
  );

  // Standard room snapshot
  static Map<String, dynamic> createRoomSnapshot({
    required String roomId,
    required String hostUsername,
    String game = 'UNO',
    List<Map<String, dynamic>>? players,
    String status = 'waiting',
    Map<String, dynamic>? rules,
  }) {
    return {
      'room_id': roomId,
      'game': game,
      'host': hostUsername,
      'status': status,
      'max_players': 10,
      'rules': rules ?? {
        'target_score': 500,
        'stacking': true,
        'bluff': true,
        'draw_to_match': false,
        'voluntary_draw_guard': true,
      },
      'players': players ?? [
        {'id': 1, 'username': 'alice', 'is_host': true, 'is_bot': false, 'cards_count': 7},
        {'id': 2, 'username': 'bob', 'is_host': false, 'is_bot': false, 'cards_count': 7},
      ],
    };
  }

  // Canonical Uno Game State
  static Map<String, dynamic> createUnoGameState({
    required String roomId,
    required int currentTurnUserId,
    required Map<String, dynamic> topCard,
    String activeColor = 'red',
    int direction = 1,
    List<Map<String, dynamic>>? myHand,
    Map<String, int>? opponentCardCounts,
    int pendingDrawCount = 0,
    String? pendingDrawType,
    bool canShoutUno = false,
    bool canCatchUno = false,
    Map<String, dynamic>? roundScores,
    Map<String, dynamic>? matchScores,
  }) {
    return {
      'room_id': roomId,
      'game': 'UNO',
      'current_turn': currentTurnUserId,
      'direction': direction,
      'active_color': activeColor,
      'top_card': topCard,
      'hand': myHand ?? [
        cardRed7,
        cardRedSkip,
        cardBlueReverse,
        cardGreenDrawTwo,
        cardWild,
      ],
      'opponents': opponentCardCounts ?? {'bob': 6, 'charlie': 7},
      'pending_draw_count': pendingDrawCount,
      'pending_draw_type': pendingDrawType,
      'can_shout_uno': canShoutUno,
      'can_catch_uno': canCatchUno,
      'round_scores': roundScores ?? {'alice': 0, 'bob': 0},
      'match_scores': matchScores ?? {'alice': 0, 'bob': 0},
      'is_match_over': false,
    };
  }

  // Arabic and English Localization catalogs for hermetic tests
  static final Map<String, String> catalogAr = {
    'app.name': "هيا نطير",
    'auth.login': "تسجيل الدخول",
    'auth.register': "إنشاء حساب",
    'auth.logout': "تسجيل الخروج",
    'auth.username': "اسم المستخدم",
    'auth.password': "كلمة المرور",
    'auth.email': "البريد الإلكتروني",
    'home.tables': "الطاولات",
    'home.friends': "الأصدقاء",
    'home.online': "المتصلون",
    'home.settings': "الإعدادات",
    'room.create': "إنشاء طاولة",
    'room.join': "انضمام إلى طاولة",
    'room.leave': "مغادرة الطاولة",
    'room.add_bot': "إضافة بوت",
    'room.remove_bot': "إزالة بوت",
    'room.start_game': "بدء اللعبة",
    'chat.send': "إرسال",
    'chat.placeholder': "اكتب رسالة...",
    'game.yourTurn': "دورك الآن.",
    'game.unoShout': "أونو!",
    'game.unoCatch': "أونو معلق! تم الإمساك به.",
    'game.drawCard': "سحب ورقة",
    'game.chooseColor': "اختر اللون",
    'game.pass': "تمرير",
    'color.red': "أحمر",
    'color.yellow': "أصفر",
    'color.green': "أخضر",
    'color.blue': "أزرق",
    'color.wild': "تغيير اللون",
  };

  static final Map<String, String> catalogEn = {
    'app.name': "Let's Fly",
    'auth.login': "Login",
    'auth.register': "Create Account",
    'auth.logout': "Log Out",
    'auth.username': "Username",
    'auth.password': "Password",
    'auth.email': "Email",
    'home.tables': "Tables",
    'home.friends': "Friends",
    'home.online': "Online Users",
    'home.settings': "Settings",
    'room.create': "Create Table",
    'room.join': "Join Table",
    'room.leave': "Leave Table",
    'room.add_bot': "Add Bot",
    'room.remove_bot': "Remove Bot",
    'room.start_game': "Start Game",
    'chat.send': "Send",
    'chat.placeholder': "Type a message...",
    'game.yourTurn': "Your turn now.",
    'game.unoShout': "UNO!",
    'game.unoCatch': "Caught! Penalty applied.",
    'game.drawCard': "Draw Card",
    'game.chooseColor': "Choose Color",
    'game.pass': "Pass",
    'color.red': "Red",
    'color.yellow': "Yellow",
    'color.green': "Green",
    'color.blue': "Blue",
    'color.wild': "Wild",
  };

  // Regex Patterns for dynamic server action translation
  static final List<Map<String, String>> translationPatterns = [
    {
      'regex': r'^لعب (.+) ورقة (.+)\.$',
      'template': r'$1 played $2.',
    },
    {
      'regex': r'^سحب (.+) ورقة من السحب\.$',
      'template': r'$1 drew a card from the deck.',
    },
    {
      'regex': r'^انضم (.+) إلى الطاولة\.$',
      'template': r'$1 joined the table.',
    },
    {
      'regex': r'^غادر (.+) الطاولة\.$',
      'template': r'$1 left the table.',
    },
    {
      'regex': r'^هتف (.+) أونو!$',
      'template': r'$1 shouted UNO!',
    },
    {
      'regex': r'^دور اللاعب (.+)\.$',
      'template': r"Player $1's turn.",
    },
  ];
}
