/// Stable semantic sound cues for Let's Fly.
/// These cues abstract physical audio filenames across shared table lifecycle
/// and all 8 game engines, conforming to the Windows reference client.
class SoundCues {
  SoundCues._();

  // Root Table & Common Lifecycle Cues
  static const String playerJoined = 'PLAYER_JOINED';
  static const String playerLeft = 'PLAYER_LEFT';
  static const String tableJoin = 'TABLE_JOIN';
  static const String tableLeave = 'TABLE_LEAVE';
  static const String turnStart = 'TURN_START';
  static const String roundStart = 'ROUND_START';
  static const String roundEnd = 'ROUND_END';
  static const String roundFinished = 'ROUND_FINISHED';
  static const String roundWon = 'ROUND_WON';
  static const String matchWin = 'MATCH_WIN';
  static const String matchLoss = 'MATCH_LOSS';
  static const String invalidAction = 'INVALID_ACTION';
  static const String gameStopped = 'GAME_STOPPED';
  static const String win = 'WIN';

  // UNO Game Audio Cues
  static const String cardDraw = 'CARD_DRAW';
  static const String cardDrawTwo = 'CARD_DRAW_TWO';
  static const String cardWildColor = 'CARD_WILD_COLOR';
  static const String cardWildDrawFour = 'CARD_WILD_DRAW_FOUR';
  static const String cardSkip = 'CARD_SKIP';
  static const String cardReverse = 'CARD_REVERSE';
  static const String unoDeal = 'UNO_DEAL';
  static const String unoPlace = 'UNO_PLACE';
  /// Canonical alias for card play audio cues (conforms to TableAudioService contract)
  static const String cardPlayed = unoPlace;
  static const String unoPlaceSpecial = 'UNO_PLACE_SPECIAL';
  static const String unoCalled = 'UNO_CALLED';
  static const String unoPenalty = 'UNO_PENALTY';
  static const String bluffChallenge = 'BLUFF_CHALLENGE';
  static const String wildColorPrompt = 'WILD_COLOR_PROMPT';
  static const String unoShuffle = 'UNO_SHUFFLE';

  // Farkle Dice Game Audio Cues
  static const String farkleRoll = 'FARKLE_ROLL';
  static const String farkleScore = 'FARKLE_SCORE';
  static const String farkleBank = 'FARKLE_BANK';
  static const String farkleBust = 'FARKLE_BUST';
  static const String farkleHotDice = 'FARKLE_HOT_DICE';

  // Thief Hunt Game Audio Cues
  static const String thiefGameStart = 'THIEF_GAME_START';
  static const String thiefEscape = 'THIEF_ESCAPE';
  static const String thiefAnswerStart = 'THIEF_ANSWER_START';
  static const String thiefRoundEnd = 'THIEF_ROUND_END';
  static const String thiefCaught = 'THIEF_CAUGHT';
  static const String thiefRoundWinner = 'THIEF_ROUND_WINNER';

  // Domino & American Domino Audio Cues
  static const String dominoPlace = 'DOMINO_PLACE';
  static const String dominoDraw = 'DOMINO_DRAW';
  static const String dominoPass = 'DOMINO_PASS';
  static const String dominoBlocked = 'DOMINO_BLOCKED';
  static const String dominoWin = 'DOMINO_WIN';
  static const String dominoShuffle = 'DOMINO_SHUFFLE';
  static const String dominoSetup = 'DOMINO_SETUP';
  static const String dominoPreRound = 'DOMINO_PRE_ROUND';
  static const String dominoRoundStart = 'DOMINO_ROUND_START';
  static const String dominoPlaceOriginal = 'DOMINO_PLACE_ORIGINAL';
  static const String dominoDrawOriginal = 'DOMINO_DRAW_ORIGINAL';

  // Snakes and Ladders Audio Cues
  static const String diceRoll = 'DICE_ROLL';
  static const String ladderClimb = 'LADDER_CLIMB';
  static const String snakeBite = 'SNAKE_BITE';
  static const String mysteryBox = 'MYSTERY_BOX';
  static const String playerBump = 'PLAYER_BUMP';
  static const String matchWinSnakes = 'MATCH_WIN_SNAKES';
  static const String freezeTrap = 'FREEZE_TRAP';
  static const String bonusRoll = 'BONUS_ROLL';
  static const String stepMove = 'STEP_MOVE';

  // Scopa Audio Cues
  static const String scopaSweep = 'SCOPA_SWEEP';
  static const String scopaPlayCard = 'SCOPA_PLAY_CARD';
  static const String scopaDeal = 'SCOPA_DEAL';
  static const String scopaShuffle = 'SCOPA_SHUFFLE';
  static const String scopaCapture = 'SCOPA_CAPTURE';
  static const String scopaRoundStart = 'SCOPA_ROUND_START';
  static const String scopaDealBatch = 'SCOPA_DEAL_BATCH';
  static const String scopaDealSingle = 'SCOPA_DEAL_SINGLE';
  static const String scopaCardThrow = 'SCOPA_CARD_THROW';
  static const String scopaEatCards = 'SCOPA_EAT_CARDS';
  static const String scopaAnnouncement = 'SCOPA_ANNOUNCEMENT';

  // Ninety-Nine (99) Audio Cues
  static const String ninetyNineDraw = 'NINETY_NINE_DRAW';
  static const String ninetyNineExceed = 'NINETY_NINE_EXCEED';
  static const String ninetyNineReach = 'NINETY_NINE_REACH';
  static const String ninetyNinePenalty = 'NINETY_NINE_PENALTY';
  static const String ninetyNineMilestone = 'NINETY_NINE_MILESTONE';
  static const String ninetyNinePlace = 'NINETY_NINE_PLACE';
  static const String ninetyNineReverse = 'NINETY_NINE_REVERSE';
  static const String ninetyNineSkip = 'NINETY_NINE_SKIP';
  static const String ninetyNinePrompt = 'NINETY_NINE_PROMPT';

  // Tennis Sound Cues (SFX & Umpire Calls)
  static const String tennisAirLeft = 'TENNIS_AIR_LEFT';
  static const String tennisAirCenter = 'TENNIS_AIR_CENTER';
  static const String tennisAirRight = 'TENNIS_AIR_RIGHT';
  static const String tennisBounceLeft = 'TENNIS_BOUNCE_LEFT';
  static const String tennisBounceCenter = 'TENNIS_BOUNCE_CENTER';
  static const String tennisBounceRight = 'TENNIS_BOUNCE_RIGHT';
  static const String tennisClaps1 = 'TENNIS_CLAPS_1';
  static const String tennisClaps2 = 'TENNIS_CLAPS_2';
  static const String tennisHit1Left = 'TENNIS_HIT_1_LEFT';
  static const String tennisHit1Center = 'TENNIS_HIT_1_CENTER';
  static const String tennisHit1Right = 'TENNIS_HIT_1_RIGHT';
  static const String tennisHit2Left = 'TENNIS_HIT_2_LEFT';
  static const String tennisHit2Center = 'TENNIS_HIT_2_CENTER';
  static const String tennisHit2Right = 'TENNIS_HIT_2_RIGHT';
  static const String tennisJmLeft = 'TENNIS_JM_LEFT';
  static const String tennisJmCenter = 'TENNIS_JM_CENTER';
  static const String tennisJmRight = 'TENNIS_JM_RIGHT';
  static const String tennisAdvantageReceiver = 'TENNIS_ADVANTAGE_RECEIVER';
  static const String tennisAdvantageServer = 'TENNIS_ADVANTAGE_SERVER';
  static const String tennisDeuce = 'TENNIS_DEUCE';
  static const String tennisFault = 'TENNIS_FAULT';
  static const String tennisGameWon = 'TENNIS_GAME_WON';
  static const String tennisMatchWon = 'TENNIS_MATCH_WON';
  static const String tennisSetWon = 'TENNIS_SET_WON';
  static const String tennisScore0_15 = 'TENNIS_SCORE_0_15';
  static const String tennisScore0_30 = 'TENNIS_SCORE_0_30';
  static const String tennisScore0_40 = 'TENNIS_SCORE_0_40';
  static const String tennisScore15_0 = 'TENNIS_SCORE_15_0';
  static const String tennisScore15_30 = 'TENNIS_SCORE_15_30';
  static const String tennisScore15_40 = 'TENNIS_SCORE_15_40';
  static const String tennisScore15All = 'TENNIS_SCORE_15_ALL';
  static const String tennisScore30_0 = 'TENNIS_SCORE_30_0';
  static const String tennisScore30_15 = 'TENNIS_SCORE_30_15';
  static const String tennisScore30_40 = 'TENNIS_SCORE_30_40';
  static const String tennisScore30All = 'TENNIS_SCORE_30_ALL';
  static const String tennisScore40_0 = 'TENNIS_SCORE_40_0';
  static const String tennisScore40_15 = 'TENNIS_SCORE_40_15';
  static const String tennisScore40_30 = 'TENNIS_SCORE_40_30';

  static const Set<String> all = {
    playerJoined, playerLeft, tableJoin, tableLeave, turnStart, roundStart,
    roundEnd, roundFinished, roundWon, matchWin, matchLoss, invalidAction,
    gameStopped, win,
    cardDraw, cardDrawTwo, cardWildColor, cardWildDrawFour, cardSkip,
    cardReverse, unoDeal, unoPlace, unoPlaceSpecial, unoCalled, unoPenalty,
    bluffChallenge, wildColorPrompt, unoShuffle,
    farkleRoll, farkleScore, farkleBank, farkleBust, farkleHotDice,
    thiefGameStart, thiefEscape, thiefAnswerStart, thiefRoundEnd,
    thiefCaught, thiefRoundWinner,
    dominoPlace, dominoDraw, dominoPass, dominoBlocked, dominoWin,
    dominoShuffle, dominoSetup, dominoPreRound, dominoRoundStart,
    dominoPlaceOriginal, dominoDrawOriginal,
    diceRoll, ladderClimb, snakeBite, mysteryBox, playerBump, matchWinSnakes,
    freezeTrap, bonusRoll, stepMove,
    scopaSweep, scopaPlayCard, scopaDeal, scopaShuffle, scopaCapture,
    scopaRoundStart, scopaDealBatch, scopaDealSingle, scopaCardThrow,
    scopaEatCards, scopaAnnouncement,
    ninetyNineDraw, ninetyNineExceed, ninetyNineReach, ninetyNinePenalty,
    ninetyNineMilestone, ninetyNinePlace, ninetyNineReverse, ninetyNineSkip,
    ninetyNinePrompt,
    tennisAirLeft, tennisAirCenter, tennisAirRight,
    tennisBounceLeft, tennisBounceCenter, tennisBounceRight,
    tennisClaps1, tennisClaps2,
    tennisHit1Left, tennisHit1Center, tennisHit1Right,
    tennisHit2Left, tennisHit2Center, tennisHit2Right,
    tennisJmLeft, tennisJmCenter, tennisJmRight,
    tennisAdvantageReceiver, tennisAdvantageServer, tennisDeuce, tennisFault,
    tennisGameWon, tennisMatchWon, tennisSetWon,
    tennisScore0_15, tennisScore0_30, tennisScore0_40,
    tennisScore15_0, tennisScore15_30, tennisScore15_40, tennisScore15All,
    tennisScore30_0, tennisScore30_15, tennisScore30_40, tennisScore30All,
    tennisScore40_0, tennisScore40_15, tennisScore40_30,
  };
}
