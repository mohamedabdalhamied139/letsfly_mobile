class MockPlayer {
  Future<void> stop() async {}
  Future<void> dispose() async {}
}

class TestEngine {
  late final MockPlayer _umpirePlayer;
  bool _initialized = false;

  void initialize() {
    _umpirePlayer = MockPlayer();
    _initialized = true;
  }

  Future<void> stopAll() async {
    await _umpirePlayer.stop();
  }

  Future<void> dispose() async {
    if (!_initialized) {
      print('Guard prevented LateInitializationError!');
      return;
    }
    await stopAll();
    await _umpirePlayer.dispose();
  }

  Future<void> disposeWithoutGuard() async {
    await stopAll();
    await _umpirePlayer.dispose();
  }
}

void main() async {
  final engine = TestEngine();
  try {
    await engine.disposeWithoutGuard();
    print('No error thrown');
  } catch (e) {
    print('THREW ERROR: $e');
  }
}
