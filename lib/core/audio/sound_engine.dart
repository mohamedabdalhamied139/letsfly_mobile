import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/sound_cues.dart';
import 'audio_voice.dart';
import 'table_audio_service.dart';

/// High-performance polyphonic sound engine for Let's Fly mobile client.
/// Conforms to TableAudioService contract and ensures TalkBack/VoiceOver
/// speech is NEVER ducked or muted by audio cues.
class SoundEngine implements TableAudioService {
  static const int poolSize = 8;
  static const String prefMasterVolume = 'sound_master_volume';
  static const String prefEffectsVolume = 'sound_effects_volume';
  static const String prefGameVolume = 'sound_game_volume';
  static const String prefMuted = 'sound_muted';

  final List<AudioVoice> _voicePool = [];
  final AudioPlayer Function()? _playerFactory;
  bool _initialized = false;
  int _roundRobinIndex = 0;

  double _masterVolume = 1.0;
  final Map<String, double> _categoryVolumes = {
    'effects': 1.0,
    'game': 1.0,
  };
  bool _muted = false;

  /// Semantic cue -> relative asset path under assets/
  /// Complete mapping for shared lifecycle and all 8 games.
  static const Map<String, String> soundRegistry = {
    // Root Table & Common Lifecycle Cues
    SoundCues.playerJoined: 'audio/player_joined.wav',
    SoundCues.playerLeft: 'audio/player_left.wav',
    SoundCues.tableJoin: 'audio/player_joined.wav',
    SoundCues.tableLeave: 'audio/player_left.wav',
    SoundCues.turnStart: 'audio/turn_start.wav',
    SoundCues.roundStart: 'audio/round_start.wav',
    SoundCues.roundEnd: 'audio/round_end.wav',
    SoundCues.roundFinished: 'audio/round_end.wav',
    SoundCues.roundWon: 'audio/round_end.wav',
    SoundCues.matchWin: 'audio/match_win.wav',
    SoundCues.matchLoss: 'audio/match_loss.wav',
    SoundCues.invalidAction: 'audio/invalid_action.wav',
    SoundCues.gameStopped: 'audio/game_stopped.wav',
    SoundCues.win: 'audio/win.wav',

    // UNO Game Audio Cues
    SoundCues.cardDraw: 'audio/uno/draw.wav',
    SoundCues.cardDrawTwo: 'audio/uno/draw_two.wav',
    SoundCues.cardWildColor: 'audio/uno/wild_color.wav',
    SoundCues.cardWildDrawFour: 'audio/uno/wild_draw_four.wav',
    SoundCues.cardSkip: 'audio/uno/skip.wav',
    SoundCues.cardReverse: 'audio/uno/reverse.wav',
    SoundCues.unoDeal: 'audio/uno/deal.wav',
    SoundCues.unoPlace: 'audio/uno/place.wav',
    'CARD_PLAYED': 'audio/uno/place.wav',
    SoundCues.unoPlaceSpecial: 'audio/uno/place_special.wav',
    SoundCues.unoCalled: 'audio/uno/uno_call.wav',
    SoundCues.unoPenalty: 'audio/uno/uno_penalty.wav',
    SoundCues.bluffChallenge: 'audio/uno/bluff_challenge.wav',
    SoundCues.wildColorPrompt: 'audio/uno/wild_color_prompt.wav',
    SoundCues.unoShuffle: 'audio/uno/shuffle.wav',

    // Farkle Dice Game Audio Cues
    SoundCues.farkleRoll: 'audio/farkle/farkle_roll.wav',
    SoundCues.farkleScore: 'audio/farkle/farkle_score.wav',
    SoundCues.farkleBank: 'audio/farkle/farkle_bank.wav',
    SoundCues.farkleBust: 'audio/farkle/farkle_bust.wav',
    SoundCues.farkleHotDice: 'audio/farkle/farkle_hot_dice.wav',

    // Thief Hunt Game Audio Cues
    SoundCues.thiefGameStart: 'audio/thief_hunt/thief_game_start.wav',
    SoundCues.thiefEscape: 'audio/thief_hunt/thief_escape.wav',
    SoundCues.thiefAnswerStart: 'audio/thief_hunt/thief_answer_start.wav',
    SoundCues.thiefRoundEnd: 'audio/thief_hunt/thief_round_end.wav',
    SoundCues.thiefCaught: 'audio/thief_hunt/thief_caught.wav',
    SoundCues.thiefRoundWinner: 'audio/thief_hunt/thief_round_winner.wav',

    // Domino Game Audio Cues (Classic & American)
    SoundCues.dominoPlace: 'audio/domino/domino_place.wav',
    SoundCues.dominoDraw: 'audio/domino/domino_draw.wav',
    SoundCues.dominoPass: 'audio/domino/domino_pass.wav',
    SoundCues.dominoBlocked: 'audio/domino/domino_blocked.wav',
    SoundCues.dominoWin: 'audio/domino/domino_win.wav',
    SoundCues.dominoShuffle: 'audio/domino/domino_shuffle.wav',
    SoundCues.dominoSetup: 'audio/domino/domino_setup.wav',
    SoundCues.dominoPreRound: 'audio/domino/domino_pre_round.wav',
    SoundCues.dominoRoundStart: 'audio/domino/domino_round_start.wav',
    SoundCues.dominoPlaceOriginal: 'audio/domino/domino_place_original.wav',
    SoundCues.dominoDrawOriginal: 'audio/domino/domino_draw_original.wav',

    // Snakes & Ladders Game Audio Cues
    SoundCues.diceRoll: 'audio/snakes_and_ladders/DICE_ROLL.wav',
    SoundCues.ladderClimb: 'audio/snakes_and_ladders/LADDER_CLIMB.wav',
    SoundCues.snakeBite: 'audio/snakes_and_ladders/SNAKE_BITE.wav',
    SoundCues.mysteryBox: 'audio/snakes_and_ladders/MYSTERY_BOX.wav',
    SoundCues.playerBump: 'audio/snakes_and_ladders/PLAYER_BUMP.wav',
    SoundCues.matchWinSnakes: 'audio/snakes_and_ladders/MATCH_WIN.wav',
    SoundCues.freezeTrap: 'audio/snakes_and_ladders/FREEZE_TRAP.wav',
    SoundCues.bonusRoll: 'audio/snakes_and_ladders/BONUS_ROLL.wav',
    SoundCues.stepMove: 'audio/snakes_and_ladders/STEP_MOVE.wav',

    // Scopa Game Audio Cues
    SoundCues.scopaSweep: 'audio/scopa/scopa_sweep.wav',
    SoundCues.scopaPlayCard: 'audio/scopa/scopa_play.wav',
    SoundCues.scopaDeal: 'audio/scopa/scopa_deal.wav',
    SoundCues.scopaShuffle: 'audio/scopa/scopa_shuffle.wav',
    SoundCues.scopaCapture: 'audio/scopa/scopa_capture.wav',
    SoundCues.scopaRoundStart: 'audio/scopa/scopa_round_start.wav',
    SoundCues.scopaDealBatch: 'audio/scopa/scopa_deal_batch.wav',
    SoundCues.scopaDealSingle: 'audio/scopa/scopa_deal_single.wav',
    SoundCues.scopaCardThrow: 'audio/scopa/scopa_card_throw.wav',
    SoundCues.scopaEatCards: 'audio/scopa/scopa_eat_cards.wav',
    SoundCues.scopaAnnouncement: 'audio/scopa/scopa_announcement.wav',

    // 99 / Ninety-Nine Game Audio Cues
    SoundCues.ninetyNineDraw: 'audio/ninety_nine/ninety_nine_draw.wav',
    SoundCues.ninetyNineExceed: 'audio/ninety_nine/ninety_nine_exceed.wav',
    SoundCues.ninetyNineReach: 'audio/ninety_nine/ninety_nine_reach.wav',
    SoundCues.ninetyNinePenalty: 'audio/ninety_nine/ninety_nine_exceed.wav',
    SoundCues.ninetyNineMilestone: 'audio/ninety_nine/ninety_nine_reach.wav',
    SoundCues.ninetyNinePlace: 'audio/uno/place.wav',
    SoundCues.ninetyNineReverse: 'audio/uno/reverse.wav',
    SoundCues.ninetyNineSkip: 'audio/uno/skip.wav',
    SoundCues.ninetyNinePrompt: 'audio/uno/wild_color_prompt.wav',

    // Tennis Game Audio Cues
    SoundCues.tennisAirLeft: 'audio/tennis/air_left.wav',
    SoundCues.tennisAirCenter: 'audio/tennis/air_center.wav',
    SoundCues.tennisAirRight: 'audio/tennis/air_right.wav',
    SoundCues.tennisBounceLeft: 'audio/tennis/bounce_left.wav',
    SoundCues.tennisBounceCenter: 'audio/tennis/bounce_center.wav',
    SoundCues.tennisBounceRight: 'audio/tennis/bounce_right.wav',
    SoundCues.tennisClaps1: 'audio/tennis/claps_1.wav',
    SoundCues.tennisClaps2: 'audio/tennis/claps_2.wav',
    SoundCues.tennisHit1Left: 'audio/tennis/hit_1_left.wav',
    SoundCues.tennisHit1Center: 'audio/tennis/hit_1_center.wav',
    SoundCues.tennisHit1Right: 'audio/tennis/hit_1_right.wav',
    SoundCues.tennisHit2Left: 'audio/tennis/hit_2_left.wav',
    SoundCues.tennisHit2Center: 'audio/tennis/hit_2_center.wav',
    SoundCues.tennisHit2Right: 'audio/tennis/hit_2_right.wav',
    SoundCues.tennisJmLeft: 'audio/tennis/jm_left.wav',
    SoundCues.tennisJmCenter: 'audio/tennis/jm_center.wav',
    SoundCues.tennisJmRight: 'audio/tennis/jm_right.wav',
    SoundCues.tennisAdvantageReceiver: 'audio/tennis/arabic_umpire/advantage_receiver.wav',
    SoundCues.tennisAdvantageServer: 'audio/tennis/arabic_umpire/advantage_server.wav',
    SoundCues.tennisDeuce: 'audio/tennis/arabic_umpire/deuce.wav',
    SoundCues.tennisFault: 'audio/tennis/arabic_umpire/fault.wav',
    SoundCues.tennisGameWon: 'audio/tennis/arabic_umpire/game_won.wav',
    SoundCues.tennisMatchWon: 'audio/tennis/arabic_umpire/match_won.wav',
    SoundCues.tennisSetWon: 'audio/tennis/arabic_umpire/set_won.wav',
    SoundCues.tennisScore0_15: 'audio/tennis/arabic_umpire/score_0_15.wav',
    SoundCues.tennisScore0_30: 'audio/tennis/arabic_umpire/score_0_30.wav',
    SoundCues.tennisScore0_40: 'audio/tennis/arabic_umpire/score_0_40.wav',
    SoundCues.tennisScore15_0: 'audio/tennis/arabic_umpire/score_15_0.wav',
    SoundCues.tennisScore15_30: 'audio/tennis/arabic_umpire/score_15_30.wav',
    SoundCues.tennisScore15_40: 'audio/tennis/arabic_umpire/score_15_40.wav',
    SoundCues.tennisScore15All: 'audio/tennis/arabic_umpire/score_15_all.wav',
    SoundCues.tennisScore30_0: 'audio/tennis/arabic_umpire/score_30_0.wav',
    SoundCues.tennisScore30_15: 'audio/tennis/arabic_umpire/score_30_15.wav',
    SoundCues.tennisScore30_40: 'audio/tennis/arabic_umpire/score_30_40.wav',
    SoundCues.tennisScore30All: 'audio/tennis/arabic_umpire/score_30_all.wav',
    SoundCues.tennisScore40_0: 'audio/tennis/arabic_umpire/score_40_0.wav',
    SoundCues.tennisScore40_15: 'audio/tennis/arabic_umpire/score_40_15.wav',
    SoundCues.tennisScore40_30: 'audio/tennis/arabic_umpire/score_40_30.wav',
  };

  final Map<String, AssetSource> _cachedSources = {};

  SoundEngine({AudioPlayer Function()? playerFactory})
      : _playerFactory = playerFactory {
    _initSources();
  }

  void _initSources() {
    soundRegistry.forEach((cue, assetPath) {
      _cachedSources[cue] = AssetSource(assetPath);
    });
  }

  List<AudioVoice> get voicePool => _voicePool;
  bool get isInitialized => _initialized;

  Future<void> initialize({SharedPreferences? prefs}) async {
    if (_initialized) return;

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: prefs?.getString('settings.audio.speaker') == 'speaker' ||
                prefs?.getString('settings.audio.speaker') == null ||
                prefs?.getString('settings.audio.speaker') == 'default',
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[SoundEngine] Global AudioContext warning: $e');
    }

    for (var i = 0; i < poolSize; i++) {
      final player = _playerFactory != null ? _playerFactory() : AudioPlayer();
      _voicePool.add(AudioVoice(id: i, player: player));
    }

    if (prefs != null) {
      _masterVolume = prefs.getDouble(prefMasterVolume) ?? prefs.getDouble('settings.audio.master_volume') ?? 1.0;
      _categoryVolumes['effects'] = prefs.getDouble(prefEffectsVolume) ?? prefs.getDouble('settings.audio.volumes.effects') ?? 1.0;
      _categoryVolumes['game'] = prefs.getDouble(prefGameVolume) ?? prefs.getDouble('settings.audio.volumes.game') ?? 1.0;
      _muted = prefs.getBool(prefMuted) ?? prefs.getBool('settings.audio.mute_all') ?? false;
    }

    _initialized = true;
  }

  String determineCategory(String cue) {
    final upper = cue.toUpperCase();
    if (upper.startsWith('UNO_') ||
        upper.startsWith('CARD_') ||
        upper.startsWith('FARKLE_') ||
        upper.startsWith('THIEF_') ||
        upper.startsWith('DOMINO_') ||
        upper.startsWith('SCOPA_') ||
        upper.startsWith('NINETY_NINE_') ||
        upper.startsWith('TENNIS_') ||
        upper == 'DICE_ROLL' ||
        upper == 'LADDER_CLIMB' ||
        upper == 'SNAKE_BITE' ||
        upper == 'MYSTERY_BOX' ||
        upper == 'PLAYER_BUMP' ||
        upper == 'MATCH_WIN_SNAKES' ||
        upper == 'FREEZE_TRAP' ||
        upper == 'BONUS_ROLL' ||
        upper == 'STEP_MOVE' ||
        upper == 'BLUFF_CHALLENGE' ||
        upper == 'WILD_COLOR_PROMPT') {
      return 'game';
    }
    return 'effects';
  }

  double getEffectiveVolume(String cue) {
    if (_muted) return 0.0;
    final cat = determineCategory(cue);
    final catVol = _categoryVolumes[cat] ?? 1.0;
    return max(0.0, min(1.0, _masterVolume * catVol));
  }

  @override
  Future<void> playCue(String cueName) async {
    if (!_initialized) {
      await initialize();
    }

    final cue = cueName.trim().toUpperCase();
    final source = _cachedSources[cue];
    if (source == null) {
      debugPrint('[SoundEngine] Unknown sound cue: $cueName (ignored)');
      return;
    }

    final volume = getEffectiveVolume(cue);
    if (volume <= 0.0 || _muted) {
      return;
    }

    final category = determineCategory(cue);

    AudioVoice? candidate;
    for (final voice in _voicePool) {
      if (!voice.isPlaying) {
        candidate = voice;
        break;
      }
    }

    if (candidate == null && _voicePool.isNotEmpty) {
      candidate = _voicePool[_roundRobinIndex];
      _roundRobinIndex = (_roundRobinIndex + 1) % _voicePool.length;
    }

    if (candidate != null) {
      await candidate.play(source, volume: volume, cue: cue, category: category);
    }
  }

  @override
  Future<void> playEvent({
    required String gameType,
    required String eventType,
    String? serverCue,
  }) async {
    final game = gameType.toUpperCase();
    final et = eventType.toUpperCase();

    if (serverCue != null && serverCue.trim().isNotEmpty) {
      final sCue = serverCue.trim().toUpperCase();
      if (soundRegistry.containsKey(sCue)) {
        await playCue(sCue);
        return;
      }
    }

    // Common lifecycle cues
    if (et == 'ROUND_END' || et == 'ROUND_FINISHED' || et == 'ROUND_WON') {
      await playCue(SoundCues.roundEnd);
      return;
    } else if (et == 'MATCH_WIN') {
      await playCue(SoundCues.matchWin);
      return;
    } else if (et == 'MATCH_LOSS') {
      await playCue(SoundCues.matchLoss);
      return;
    } else if (et == 'GAME_STOPPED') {
      await playCue(SoundCues.gameStopped);
      return;
    } else if (et == 'INVALID_ACTION' || et == 'CANNOT_MOVE') {
      await playCue(SoundCues.invalidAction);
      return;
    }

    switch (game) {
      case 'UNO':
        switch (et) {
          case 'GAME_STARTED':
          case 'ROUND_START':
          case 'ROUND_STARTED':
            await playCue(SoundCues.unoDeal);
            break;
          case 'CARD_DRAWN':
          case 'CARD_DRAWN_AND_PASSED':
            await playCue(SoundCues.cardDraw);
            break;
          case 'DRAW_PENALTY':
          case 'BUZZER_PENALTY':
            await playCue(SoundCues.cardDrawTwo);
            break;
          case 'CARD_PLAYED':
            await playCue(SoundCues.unoPlace);
            break;
          case 'SPECIAL_CARD_PLAYED':
          case 'BUZZER_STARTED':
            await playCue(SoundCues.unoPlaceSpecial);
            break;
          case 'BLUFF_CAUGHT':
          case 'BLUFF_FALSE':
            await playCue(SoundCues.bluffChallenge);
            break;
          case 'UNO_CALLED':
            await playCue(SoundCues.unoCalled);
            break;
          case 'UNO_CAUGHT':
            await playCue(SoundCues.unoPenalty);
            break;
        }
        break;

      case 'FARKLE':
        switch (et) {
          case 'DICE_ROLLED':
            await playCue(SoundCues.farkleRoll);
            break;
          case 'COMBINATION_SCORED':
            await playCue(SoundCues.farkleScore);
            break;
          case 'HOT_DICE':
            await playCue(SoundCues.farkleHotDice);
            break;
          case 'TURN_BANKED':
            await playCue(SoundCues.farkleBank);
            break;
          case 'FARKLE':
            await playCue(SoundCues.farkleBust);
            break;
        }
        break;

      case 'THIEF_HUNT':
        switch (et) {
          case 'GAME_STARTED':
            await playCue(SoundCues.thiefGameStart);
            break;
          case 'ESCAPE_START':
            await playCue(SoundCues.thiefEscape);
            break;
          case 'ANSWER_START':
            await playCue(SoundCues.thiefAnswerStart);
            break;
          case 'ROUND_WIN':
            await playCue(SoundCues.thiefRoundWinner);
            break;
          case 'ROUND_TIE':
          case 'PLAYER_ELIMINATED':
          case 'THIEF_WIN':
            await playCue(SoundCues.thiefRoundEnd);
            break;
          case 'THIEF_CAUGHT':
            await playCue(SoundCues.thiefCaught);
            break;
        }
        break;

      case 'SCOPA':
        switch (et) {
          case 'GAME_STARTED':
            await playCue(SoundCues.scopaDeal);
            break;
          case 'ROUND_START':
          case 'ROUND_STARTED':
            await playCue(SoundCues.scopaRoundStart);
            break;
          case 'DEAL_BATCH':
            await playCue(SoundCues.scopaDealBatch);
            break;
          case 'CARD_PLAYED':
            await playCue(SoundCues.scopaCardThrow);
            break;
          case 'CARD_CAPTURED':
            await playCue(SoundCues.scopaEatCards);
            break;
          case 'SCOPA_SWEEP':
            await playCue(SoundCues.scopaAnnouncement);
            break;
        }
        break;

      case 'DOMINO':
        switch (et) {
          case 'GAME_STARTED':
          case 'ROUND_START':
          case 'ROUND_STARTED':
            await playCue(SoundCues.dominoPreRound);
            break;
          case 'TILE_PLACED':
            await playCue(SoundCues.dominoPlaceOriginal);
            break;
          case 'TILE_DRAWN':
            await playCue(SoundCues.dominoDrawOriginal);
            break;
          case 'PLAYER_PASSED':
            await playCue(SoundCues.dominoPass);
            break;
          case 'ROUND_BLOCKED':
            await playCue(SoundCues.dominoBlocked);
            break;
          case 'DOMINO_WIN':
            await playCue(SoundCues.dominoWin);
            break;
        }
        break;

      case 'AMERICAN_DOMINO':
        switch (et) {
          case 'GAME_STARTED':
          case 'ROUND_START':
          case 'ROUND_STARTED':
            await playCue(SoundCues.dominoShuffle);
            break;
          case 'TILE_PLACED':
            await playCue(SoundCues.dominoPlace);
            break;
          case 'TILE_DRAWN':
            await playCue(SoundCues.dominoDraw);
            break;
          case 'PLAYER_PASSED':
            await playCue(SoundCues.dominoPass);
            break;
          case 'ROUND_BLOCKED':
            await playCue(SoundCues.dominoBlocked);
            break;
          case 'DOMINO_WIN':
            await playCue(SoundCues.dominoWin);
            break;
        }
        break;

      case 'SNAKES_LADDERS':
        switch (et) {
          case 'DICE_ROLLED':
            await playCue(SoundCues.diceRoll);
            break;
          case 'BONUS_ROLL':
            await playCue(SoundCues.bonusRoll);
            break;
          case 'PLAYER_FROZEN':
            await playCue(SoundCues.freezeTrap);
            break;
          case 'STEP_MOVE':
            await playCue(SoundCues.stepMove);
            break;
          case 'LADDER_CLIMB':
            await playCue(SoundCues.ladderClimb);
            break;
          case 'SNAKE_BITE':
            await playCue(SoundCues.snakeBite);
            break;
          case 'MYSTERY_BOX':
            await playCue(SoundCues.mysteryBox);
            break;
          case 'PLAYER_BUMP':
            await playCue(SoundCues.playerBump);
            break;
        }
        break;

      case 'NINETY_NINE':
        switch (et) {
          case 'CARD_PLAYED':
            await playCue(SoundCues.ninetyNinePlace);
            break;
          case 'PENDING_CHOICE':
            await playCue(SoundCues.ninetyNinePrompt);
            break;
          case 'CARD_DRAWN':
            await playCue(SoundCues.ninetyNineDraw);
            break;
          case 'EXCEED':
          case 'PENALTY':
            await playCue(SoundCues.ninetyNineExceed);
            break;
          case 'REACH':
          case 'MILESTONE':
            await playCue(SoundCues.ninetyNineReach);
            break;
        }
        break;
    }
  }

  @override
  void setMasterVolume(double volume) {
    _masterVolume = max(0.0, min(1.0, volume));
    _updateAllVoiceVolumes();
  }

  @override
  void setCategoryVolume(String category, double volume) {
    if (_categoryVolumes.containsKey(category)) {
      _categoryVolumes[category] = max(0.0, min(1.0, volume));
      _updateAllVoiceVolumes();
    }
  }

  @override
  void setMute(bool muted) {
    _muted = muted;
    _updateAllVoiceVolumes();
  }

  void _updateAllVoiceVolumes() {
    for (final voice in _voicePool) {
      if (voice.isPlaying && voice.currentCue != null) {
        final vol = getEffectiveVolume(voice.currentCue!);
        voice.setVolume(vol);
      }
    }
  }

  @override
  double get masterVolume => _masterVolume;

  double getCategoryVolume(String category) => _categoryVolumes[category] ?? 1.0;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> stopAll() async {
    for (final voice in _voicePool) {
      await voice.stop();
    }
  }

  @override
  Future<void> dispose() async {
    for (final voice in _voicePool) {
      await voice.dispose();
    }
    _voicePool.clear();
    _initialized = false;
  }
}
