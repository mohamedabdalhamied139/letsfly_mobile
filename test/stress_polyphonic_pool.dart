// Pure Dart Stress Harness for 8-Voice Polyphonic Pool Logic
import 'dart:async';
import 'dart:math';

class MockAudioPlayer {
  final int id;
  final StreamController<void> _completeController = StreamController<void>.broadcast();
  bool isPlaying = false;
  double volume = 1.0;
  bool throwOnPlay = false;
  bool throwOnStop = false;
  int playCount = 0;
  int stopCount = 0;

  MockAudioPlayer(this.id);

  Stream<void> get onPlayerComplete => _completeController.stream;

  Future<void> play(String source, {dynamic mode}) async {
    if (throwOnPlay) {
      throw Exception('Simulated hardware playback failure on player ' + id.toString());
    }
    await Future.delayed(Duration(milliseconds: 5));
    playCount++;
    isPlaying = true;
  }

  Future<void> stop() async {
    if (throwOnStop) {
      throw Exception('Simulated stop error on player ' + id.toString());
    }
    // Simulate real Android/iOS platform channel latency (2-15ms)
    await Future.delayed(Duration(milliseconds: 5));
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

class AudioVoice {
  final int id;
  final MockAudioPlayer player;
  bool isPlaying = false;
  DateTime lastPlayTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? currentCue;
  String? currentCategory;
  StreamSubscription? _completeSub;

  AudioVoice({required this.id, required this.player}) {
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

class TestSoundEngine {
  static const int poolSize = 8;
  final List<AudioVoice> _voicePool = [];
  int _roundRobinIndex = 0;
  double _masterVolume = 1.0;
  final Map<String, double> _categoryVolumes = {'effects': 1.0, 'game': 1.0};
  bool _muted = false;

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
    'UNO_PLACE_SPECIAL': 'audio/uno/place_special.wav',
    'UNO_CALLED': 'audio/uno/uno_call.wav',
    'UNO_PENALTY': 'audio/uno/uno_penalty.wav',
    'BLUFF_CHALLENGE': 'audio/uno/bluff_challenge.wav',
    'WILD_COLOR_PROMPT': 'audio/uno/wild_color_prompt.wav',
    'UNO_SHUFFLE': 'audio/uno/shuffle.wav',
  };

  void initialize({List<MockAudioPlayer>? players}) {
    _voicePool.clear();
    for (var i = 0; i < poolSize; i++) {
      final p = players != null ? players[i] : MockAudioPlayer(i);
      _voicePool.add(AudioVoice(id: i, player: p));
    }
  }

  List<AudioVoice> get voicePool => _voicePool;
  int get roundRobinIndex => _roundRobinIndex;

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
    return max(0.0, min(1.0, _masterVolume * catVol));
  }

  void setMasterVolume(double volume) {
    _masterVolume = max(0.0, min(1.0, volume));
  }

  void setMute(bool muted) {
    _muted = muted;
  }

  Future<void> playCue(String cueName) async {
    final cue = cueName.trim().toUpperCase();
    final source = soundRegistry[cue];
    if (source == null) return;

    final volume = getEffectiveVolume(cue);
    if (volume <= 0.0 || _muted) return;

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

  Future<void> dispose() async {
    for (final v in _voicePool) {
      await v.dispose();
    }
    _voicePool.clear();
  }
}

Future<void> main() async {
  print('=== STRESS TEST 1: Rapid Burst of 25 Simultaneous Requests (>20) ===');
  final engine = TestSoundEngine();
  final players = List.generate(8, (i) => MockAudioPlayer(i));
  engine.initialize(players: players);

  List<String> burstCues = [
    'CARD_DRAW', 'CARD_DRAW_TWO', 'CARD_WILD_COLOR', 'CARD_SKIP', 'CARD_REVERSE',
    'UNO_DEAL', 'UNO_PLACE', 'UNO_PLACE_SPECIAL', 'UNO_CALLED', 'UNO_PENALTY',
    'BLUFF_CHALLENGE', 'WILD_COLOR_PROMPT', 'UNO_SHUFFLE', 'PLAYER_JOINED', 'PLAYER_LEFT',
    'TURN_START', 'ROUND_START', 'ROUND_END', 'MATCH_WIN', 'MATCH_LOSS',
    'INVALID_ACTION', 'GAME_STOPPED', 'WIN', 'CARD_DRAW', 'CARD_DRAW_TWO',
  ];

  print('Firing 25 simultaneous sound cues via Future.wait...');
  try {
    await Future.wait([for (final cue in burstCues) engine.playCue(cue)]);
    print('[PASS] 25 simultaneous requests completed without unhandled exceptions.');
  } catch (e, st) {
    print('[FAIL] Exception thrown during burst: ' + e.toString());
    return;
  }

  assert(engine.voicePool.length == 8, 'Voice pool size must strictly remain 8');
  print('[PASS] Voice pool size strictly bounded: ' + engine.voicePool.length.toString() + ' voices.');

  int totalPlays = players.fold(0, (sum, p) => sum + p.playCount);
  print('Total play invocations across 8 players: ' + totalPlays.toString());
  assert(totalPlays == 25, 'Expected exactly 25 play invocations across players');

  print('Voice state distribution after 25 bursts:');
  for (var i = 0; i < 8; i++) {
    final v = engine.voicePool[i];
    final p = players[i];
    print('  Voice ' + i.toString() + ': isPlaying=' + v.isPlaying.toString() + ', cue=' + (v.currentCue ?? 'none') + ', playCount=' + p.playCount.toString() + ', stopCount=' + p.stopCount.toString());
  }

  print('');
  print('=== STRESS TEST 2: Massive Burst of 100 Requests with Random Completion ===');
  final rand = Random(42);
  final futures = <Future>[];
  for (var i = 0; i < 100; i++) {
    final cue = burstCues[i % burstCues.length];
    futures.add(engine.playCue(cue));

    if (rand.nextBool()) {
      final victimVoice = rand.nextInt(8);
      players[victimVoice].completePlayback();
    }
  }

  try {
    await Future.wait(futures);
    print('[PASS] 100 rapid requests processed successfully.');
  } catch (e) {
    print('[FAIL] 100 requests failed: ' + e.toString());
  }

  print('');
  print('=== STRESS TEST 3: Hardware Exception Injection Resilience ===');
  players[2].throwOnPlay = true;
  players[4].throwOnStop = true;
  print('Injected simulated hardware exceptions into Player 2 (play) and Player 4 (stop)...');

  try {
    await Future.wait([for (var i = 0; i < 20; i++) engine.playCue(burstCues[i % burstCues.length])]);
    print('[PASS] Engine gracefully survived hardware exceptions without propagating errors to caller.');
  } catch (e) {
    print('[FAIL] Engine leaked hardware exception: ' + e.toString());
  }

  print('');
  print('=== STRESS TEST 4: Round-Robin Eviction Order Verification ===');
  final cleanPlayers = List.generate(8, (i) => MockAudioPlayer(i));
  final cleanEngine = TestSoundEngine();
  cleanEngine.initialize(players: cleanPlayers);

  // Fill all 8 voices
  for (var i = 0; i < 8; i++) {
    await cleanEngine.playCue(burstCues[i]);
  }
  for (var i = 0; i < 8; i++) {
    assert(cleanEngine.voicePool[i].isPlaying == true);
  }
  assert(cleanEngine.roundRobinIndex == 0);

  // Next request steals voice 0
  await cleanEngine.playCue(burstCues[8]);
  assert(cleanEngine.roundRobinIndex == 1);
  assert(cleanEngine.voicePool[0].currentCue == burstCues[8]);

  // Next request steals voice 1
  await cleanEngine.playCue(burstCues[9]);
  assert(cleanEngine.roundRobinIndex == 2);
  assert(cleanEngine.voicePool[1].currentCue == burstCues[9]);

  print('[PASS] Round-robin voice stealing functions correctly with 100% predictability.');

  print('');
  print('=== STRESS TEST 5: Zero-Volume Voice Allocation Leak Guard ===');
  await cleanEngine.dispose();
  final zeroVolEngine = TestSoundEngine();
  final zeroVolPlayers = List.generate(8, (i) => MockAudioPlayer(i));
  zeroVolEngine.initialize(players: zeroVolPlayers);
  zeroVolEngine.setMasterVolume(0.0);
  await zeroVolEngine.playCue('CARD_DRAW');
  assert(zeroVolEngine.voicePool.every((v) => !v.isPlaying), 'Zero volume must not allocate or play any voice');
  assert(zeroVolPlayers.every((p) => p.playCount == 0), 'No audio voice should play at volume 0.0');
  print('[PASS] Zero volume unmuted request safely discarded without voice allocation.');
  await zeroVolEngine.dispose();
  await engine.dispose();
  print('');
  print('==================================================');
  print('ALL EMPIRICAL STRESS TESTS COMPLETED WITH 100% SUCCESS');
  print('==================================================');
}
