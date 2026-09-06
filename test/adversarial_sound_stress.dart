// Adversarial Empirical Stress & Concurrency Suite for Sound Engine & Polyphonic Pool
import 'dart:async';
import 'dart:math';

class AdversarialMockPlayer {
  final int id;
  final StreamController<void> _completeController = StreamController<void>.broadcast();
  bool isPlaying = false;
  double volume = 1.0;
  bool throwOnPlay = false;
  bool throwOnStop = false;
  int playCount = 0;
  int stopCount = 0;
  int simulatedLatencyMs;

  AdversarialMockPlayer(this.id, {this.simulatedLatencyMs = 5});

  Stream<void> get onPlayerComplete => _completeController.stream;

  Future<void> play(String source, {dynamic mode}) async {
    if (throwOnPlay) {
      throw Exception('Hardware playback error on player $id');
    }
    if (simulatedLatencyMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedLatencyMs));
    }
    playCount++;
    isPlaying = true;
  }

  Future<void> stop() async {
    if (throwOnStop) {
      throw Exception('Hardware stop error on player $id');
    }
    if (simulatedLatencyMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedLatencyMs));
    }
    stopCount++;
    isPlaying = false;
  }

  Future<void> setVolume(double vol) async {
    volume = vol;
  }

  Future<void> dispose() async {
    await _completeController.close();
  }

  void completePlayback() {
    if (isPlaying) {
      isPlaying = false;
      _completeController.add(null);
    }
  }
}

class TestAudioVoice {
  final int id;
  final AdversarialMockPlayer player;
  bool isPlaying = false;
  DateTime lastPlayTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? currentCue;
  String? currentCategory;
  StreamSubscription? _completeSub;
  int generation = 0;

  TestAudioVoice({required this.id, required this.player}) {
    _completeSub = player.onPlayerComplete.listen((_) {
      isPlaying = false;
      currentCue = null;
      currentCategory = null;
    });
  }

  Future<void> play(
    String source, {
    required double volume,
    required String cue,
    required String category,
  }) async {
    isPlaying = true;
    lastPlayTime = DateTime.now();
    currentCue = cue;
    currentCategory = category;
    generation++;

    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(source);
    } catch (_) {
      isPlaying = false;
    }
  }

  Future<void> stop() async {
    isPlaying = false;
    currentCue = null;
    currentCategory = null;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    if (isPlaying) {
      try {
        await player.setVolume(volume);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _completeSub?.cancel();
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }
}

class AdversarialSoundEngine {
  static const int poolSize = 8;
  final List<TestAudioVoice> _voicePool = [];
  int _roundRobinIndex = 0;
  double _masterVolume = 1.0;
  final Map<String, double> _categoryVolumes = {'effects': 1.0, 'game': 1.0};
  bool _muted = false;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  final Map<String, String> soundRegistry = {
    'PLAYER_JOINED': 'audio/player_joined.wav',
    'PLAYER_LEFT': 'audio/player_left.wav',
    'TURN_START': 'audio/turn_start.wav',
    'ROUND_START': 'audio/round_start.wav',
    'ROUND_END': 'audio/round_end.wav',
    'MATCH_WIN': 'audio/match_win.wav',
    'MATCH_LOSS': 'audio/match_loss.wav',
    'INVALID_ACTION': 'audio/invalid_action.wav',
    'GAME_STOPPED': 'audio/game_stopped.wav',
    'WIN': 'audio/win.wav',
    'CARD_DRAW': 'audio/uno/draw.wav',
    'CARD_DRAW_TWO': 'audio/uno/draw_two.wav',
    'CARD_WILD_COLOR': 'audio/uno/wild_color.wav',
    'CARD_WILD_DRAW_FOUR': 'audio/uno/wild_draw_four.wav',
    'CARD_SKIP': 'audio/uno/skip.wav',
    'CARD_REVERSE': 'audio/uno/reverse.wav',
    'UNO_DEAL': 'audio/uno/deal.wav',
    'UNO_PLACE': 'audio/uno/place.wav',
    'CARD_PLAYED': 'audio/uno/place.wav',
    'UNO_PLACE_SPECIAL': 'audio/uno/place_special.wav',
    'UNO_CALLED': 'audio/uno/uno_call.wav',
    'UNO_PENALTY': 'audio/uno/uno_penalty.wav',
    'BLUFF_CHALLENGE': 'audio/uno/bluff_challenge.wav',
    'WILD_COLOR_PROMPT': 'audio/uno/wild_color_prompt.wav',
    'UNO_SHUFFLE': 'audio/uno/shuffle.wav',
  };

  final List<AdversarialMockPlayer> players;

  AdversarialSoundEngine({List<AdversarialMockPlayer>? mockPlayers})
      : players = mockPlayers ?? List.generate(8, (i) => AdversarialMockPlayer(i));

  Future<void> initialize({int simulatedInitDelayMs = 0}) async {
    if (_initialized) return;

    if (simulatedInitDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedInitDelayMs));
    }

    if (_voicePool.isEmpty) {
      for (var i = 0; i < poolSize; i++) {
        _voicePool.add(TestAudioVoice(id: i, player: players[i]));
      }
    }
    _initialized = true;
  }

  List<TestAudioVoice> get voicePool => _voicePool;
  int get roundRobinIndex => _roundRobinIndex;
  bool get isInitialized => _initialized;

  String determineCategory(String cue) {
    final upper = cue.toUpperCase();
    if (upper.startsWith('UNO_') ||
        upper.startsWith('CARD_') ||
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
    return (max(0.0, min(1.0, _masterVolume * catVol)));
  }

  void setMasterVolume(double volume) {
    _masterVolume = max(0.0, min(1.0, volume));
    _updateAllVoiceVolumes();
  }

  void setCategoryVolume(String category, double volume) {
    if (_categoryVolumes.containsKey(category)) {
      _categoryVolumes[category] = max(0.0, min(1.0, volume));
      _updateAllVoiceVolumes();
    }
  }

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

  Future<void> playCue(String cueName) async {
    if (!_initialized) {
      await initialize();
    }

    final cue = cueName.trim().toUpperCase();
    final source = soundRegistry[cue];
    if (source == null) return;

    final volume = getEffectiveVolume(cue);
    if (volume <= 0.0 || _muted) return;

    final category = determineCategory(cue);

    TestAudioVoice? candidate;
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

  Future<void> dispose() async {
    for (final v in _voicePool) {
      await v.dispose();
    }
    _voicePool.clear();
    _initialized = false;
  }
}

Future<void> main() async {
  print('===============================================================');
  print('   ADVERSARIAL STRESS HARNESS: SOUND ENGINE & CONCURRENCY');
  print('===============================================================\n');

  int totalChallenges = 0;
  int passedChallenges = 0;

  void reportResult(String name, bool passed, [String? detail]) {
    totalChallenges++;
    if (passed) {
      passedChallenges++;
      print('  [PASS] Challenge $totalChallenges: $name');
    } else {
      print('  [FAIL] Challenge $totalChallenges: $name -> $detail');
    }
  }

  // --- CHALLENGE 1: Extreme Burst Concurrency (50 simultaneous cues) ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    final cues = [
      'CARD_DRAW', 'CARD_DRAW_TWO', 'CARD_WILD_COLOR', 'CARD_SKIP', 'CARD_REVERSE',
      'UNO_DEAL', 'UNO_PLACE', 'CARD_PLAYED', 'UNO_PLACE_SPECIAL', 'UNO_CALLED',
      'UNO_PENALTY', 'BLUFF_CHALLENGE', 'WILD_COLOR_PROMPT', 'UNO_SHUFFLE',
      'PLAYER_JOINED', 'PLAYER_LEFT', 'TURN_START', 'ROUND_START', 'ROUND_END',
      'MATCH_WIN', 'MATCH_LOSS', 'INVALID_ACTION', 'GAME_STOPPED', 'WIN',
    ];
    final burstList = List.generate(50, (i) => cues[i % cues.length]);
    await Future.wait([for (final c in burstList) engine.playCue(c)]);

    final totalPlays = engine.players.fold<int>(0, (s, p) => s + p.playCount);
    reportResult(
      '50 simultaneous bursts: Voice pool bounded to 8, plays == 50',
      engine.voicePool.length == 8 && totalPlays == 50,
      'pool=${engine.voicePool.length}, totalPlays=$totalPlays',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 2: SoundCues.cardPlayed alias parity & resolution ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    await engine.playCue('CARD_PLAYED');
    await engine.playCue('UNO_PLACE');
    final p0 = engine.players[0].playCount;
    final p1 = engine.players[1].playCount;
    final voice0Cue = engine.voicePool[0].currentCue;
    final voice1Cue = engine.voicePool[1].currentCue;
    reportResult(
      'SoundCues.cardPlayed resolves to audio/uno/place.wav cleanly',
      p0 == 1 && p1 == 1 && voice0Cue == 'CARD_PLAYED' && voice1Cue == 'UNO_PLACE',
      'p0=$p0, p1=$p1, voice0=$voice0Cue, voice1=$voice1Cue',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 3: Zero-volume guard with master=0.0, category=1.0, unmuted ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    engine.setMasterVolume(0.0);
    // Fire 30 cues across all categories
    final testCues = ['CARD_PLAYED', 'PLAYER_JOINED', 'UNO_DEAL', 'TURN_START', 'WIN'];
    await Future.wait([for (var i = 0; i < 30; i++) engine.playCue(testCues[i % testCues.length])]);
    final totalPlays = engine.players.fold<int>(0, (s, p) => s + p.playCount);
    final anyPlaying = engine.voicePool.any((v) => v.isPlaying);
    reportResult(
      'Zero-volume guard (master=0.0): 30 cues completely discarded (0 plays, 0 active voices)',
      totalPlays == 0 && !anyPlaying,
      'totalPlays=$totalPlays, anyPlaying=$anyPlaying',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 4: Zero-volume guard with game-category volume=0.0, master=1.0 ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    engine.setCategoryVolume('game', 0.0);
    // Fire game cue ('CARD_PLAYED') vs effects cue ('PLAYER_JOINED')
    await engine.playCue('CARD_PLAYED'); // game -> volume 0.0 -> must discard
    await engine.playCue('UNO_PLACE');   // game -> volume 0.0 -> must discard
    await engine.playCue('PLAYER_JOINED'); // effects -> volume 1.0 -> must play
    final totalPlays = engine.players.fold<int>(0, (s, p) => s + p.playCount);
    reportResult(
      'Category-level zero-volume guard: game discarded, effects plays',
      totalPlays == 1 && engine.voicePool[0].currentCue == 'PLAYER_JOINED',
      'totalPlays=$totalPlays, voice0Cue=${engine.voicePool[0].currentCue}',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 5: Mute guard with volume=1.0 ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    engine.setMute(true);
    await Future.wait([for (var i = 0; i < 25; i++) engine.playCue('CARD_PLAYED')]);
    final totalPlays = engine.players.fold<int>(0, (s, p) => s + p.playCount);
    reportResult(
      'Mute guard (_muted=true): 25 cues discarded without voice allocation',
      totalPlays == 0,
      'totalPlays=$totalPlays',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 6: Negative/out-of-bounds volume clamping ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    engine.setMasterVolume(-100.0);
    await engine.playCue('CARD_PLAYED');
    final playsAtNeg = engine.players.fold<int>(0, (s, p) => s + p.playCount);

    engine.setMasterVolume(100.0);
    await engine.playCue('CARD_PLAYED');
    final playsAtPos = engine.players.fold<int>(0, (s, p) => s + p.playCount);
    final voice0Vol = engine.players[0].volume;

    reportResult(
      'Volume clamping: negative clamped to 0.0 (discarded), excessive clamped to 1.0',
      playsAtNeg == 0 && playsAtPos == 1 && voice0Vol == 1.0,
      'playsAtNeg=$playsAtNeg, playsAtPos=$playsAtPos, voice0Vol=$voice0Vol',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 7: Exact Round-Robin Voice Eviction Order (24 sequential steals) ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    // Fill all 8
    for (var i = 0; i < 8; i++) {
      await engine.playCue('TURN_START');
    }
    // Now steal all 8 voices three full times (24 steals)
    bool evictionOrderCorrect = true;
    for (var cycle = 0; cycle < 3; cycle++) {
      for (var expectedVoice = 0; expectedVoice < 8; expectedVoice++) {
        final expectedNextIndex = (expectedVoice + 1) % 8;
        if (engine.roundRobinIndex != expectedVoice) {
          evictionOrderCorrect = false;
        }
        await engine.playCue('WIN');
        if (engine.roundRobinIndex != expectedNextIndex) {
          evictionOrderCorrect = false;
        }
      }
    }
    reportResult(
      'Predictable round-robin voice stealing across 3 full cycles (24 steals)',
      evictionOrderCorrect,
      'evictionOrderCorrect=$evictionOrderCorrect',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 8: Massive Mixed Concurrent Stress (100 operations with random completion & volume jitter) ---
  {
    final rand = Random(999);
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    final testCues = [
      'CARD_DRAW', 'CARD_DRAW_TWO', 'CARD_PLAYED', 'UNO_PLACE', 'WIN',
      'TURN_START', 'PLAYER_JOINED', 'MATCH_WIN', 'INVALID_ACTION',
    ];

    final futures = <Future>[];
    for (var i = 0; i < 100; i++) {
      final cue = testCues[rand.nextInt(testCues.length)];
      futures.add(engine.playCue(cue));

      if (i % 10 == 0) {
        engine.setMasterVolume(rand.nextDouble());
      }
      if (i % 15 == 0) {
        final vId = rand.nextInt(8);
        engine.players[vId].completePlayback();
      }
    }
    await Future.wait(futures);
    reportResult(
      '100 mixed concurrent operations (volume jitter + random completion): No deadlocks or leaks',
      engine.voicePool.length == 8,
      'pool=${engine.voicePool.length}',
    );
    await engine.dispose();
  }

  // --- CHALLENGE 9: Hardware Fault Injection during high load ---
  {
    final engine = AdversarialSoundEngine();
    await engine.initialize();
    engine.players[1].throwOnPlay = true;
    engine.players[3].throwOnStop = true;
    engine.players[5].throwOnPlay = true;

    bool survived = true;
    try {
      await Future.wait([
        for (var i = 0; i < 40; i++) engine.playCue('CARD_PLAYED'),
      ]);
    } catch (e) {
      survived = false;
    }

    reportResult(
      'Survives simultaneous hardware faults across multiple pooled players without unhandled rejections',
      survived,
      'survived=$survived',
    );
    await engine.dispose();
  }

  print('\n===============================================================');
  print('RESULTS: $passedChallenges / $totalChallenges CHALLENGES PASSED');
  print('===============================================================');

  if (passedChallenges != totalChallenges) {
    throw Exception('Adversarial stress suite detected failures!');
  }
}
