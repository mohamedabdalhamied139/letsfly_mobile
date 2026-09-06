import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../../data/repositories/room_ws_service.dart';
import 'voice_codec.dart';

/// Android/iOS implementation of the Windows table voice contract.
/// Voice is opt-in, room-scoped, muted by default and uses the same LFV1/LFS1
/// wire format as the authoritative Windows client/server.
class VoiceChatService {
  final RoomWsService roomWs;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _playbackQueue = <Uint8List>[];
  StreamSubscription<void>? _playerCompleteSub;
  bool _playingVoicePacket = false;
  StreamSubscription<List<int>>? _packetSub;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  Completer<bool>? _joinCompleter;
  StreamSubscription<Uint8List>? _captureSub;
  String? roomId;
  bool sessionActive = false;
  bool muted = true;
  bool _starting = false;
  bool _restoreVoiceAfterReconnect = false;

  VoiceChatService({required this.roomWs}) {
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      _playingVoicePacket = false;
      _pumpVoicePlayback();
    });
  }

  Future<void> _setVoipAudioContext() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true, // Loudspeaker via voice call stream!
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            audioMode: AndroidAudioMode.inCommunication,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _restoreNormalAudioContext() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            audioMode: AndroidAudioMode.normal,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> attach(String id) async {
    final next = id.trim();
    if (next.isEmpty) { await detach(); return; }
    if (roomId == next) return;
    await detach();
    roomId = next;
    _packetSub = roomWs.voicePacketStream.listen(_handlePacket);
    _eventSub = roomWs.rawEventStream.listen(_handleRoomEvent);
  }

  Future<void> detach() async {
    await leaveSession();
    await _packetSub?.cancel();
    await _eventSub?.cancel();
    _packetSub = null;
    _eventSub = null;
    roomId = null;
    await _restoreNormalAudioContext();
  }

  Future<bool> toggleSession() async {
    if (sessionActive) { await leaveSession(); return false; }
    return joinSession();
  }

  void suspendForReconnect() {
    if (sessionActive) {
      _restoreVoiceAfterReconnect = true;
      roomWs.sendJson({'type': 'voice_leave'}).catchError((_) {});
      sessionActive = false;
    }
    mute();
  }

  Future<void> restoreAfterReconnect() async {
    if (!_restoreVoiceAfterReconnect) return;
    _restoreVoiceAfterReconnect = false;
    if (roomId == null || roomId!.isEmpty) return;
    final joined = await joinSession();
    if (joined) await unmute();
  }

  Future<bool> joinSession() async {
    if (roomId == null || roomId!.isEmpty || sessionActive) return sessionActive;
    if (_starting && _joinCompleter != null) return _joinCompleter!.future;
    _starting = true;
    final completer = Completer<bool>();
    _joinCompleter = completer;
    try {
      await _setVoipAudioContext();
      await roomWs.sendJson({'type': 'voice_join'});
      final joined = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
        sessionActive = false;
        return false;
      });
      if (!joined) {
        await _restoreNormalAudioContext();
      }
      return joined;
    } catch (_) {
      sessionActive = false;
      await _restoreNormalAudioContext();
      return false;
    } finally {
      _starting = false;
      if (identical(_joinCompleter, completer)) _joinCompleter = null;
    }
  }

  void _handleRoomEvent(Map<String, dynamic> event) {
    if (event['type'] != 'voice_joined') return;
    final eventRoom = '${event['room_id'] ?? ''}';
    if (roomId == null || eventRoom != roomId) return;
    sessionActive = true;
    muted = true;
    final completer = _joinCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(true);
  }

  Future<void> leaveSession() async {
    if (sessionActive) {
      try { await roomWs.sendJson({'type': 'voice_leave'}); } catch (_) {}
    }
    sessionActive = false;
    _restoreVoiceAfterReconnect = false;
    muted = true;
    await mute();
    await _restoreNormalAudioContext();
  }

  Future<bool> toggleMute() async {
    if (!sessionActive) return false;
    if (muted) return unmute();
    await mute();
    return false;
  }

  final List<int> _captureBuffer = [];

  Future<bool> unmute() async {
    if (!sessionActive) return false;
    if (await _recorder.hasPermission() == false) return false;
    if (_captureSub != null) { muted = false; return true; }
    try {
      _captureBuffer.clear();
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _captureSub = stream.listen((chunk) {
        if (!muted && sessionActive && roomId != null && chunk.isNotEmpty) {
          _captureBuffer.addAll(chunk);
          // 640 bytes = 320 samples @ 16-bit mono 16kHz (20ms frame)
          while (_captureBuffer.length >= 640) {
            final frame = Uint8List.fromList(_captureBuffer.sublist(0, 640));
            _captureBuffer.removeRange(0, 640);
            final packet = encodePcm16(frame);
            if (packet.isNotEmpty) {
              roomWs.sendBytes(packet).catchError((_) {});
            }
          }
        }
      });
      muted = false;
      return true;
    } catch (_) { return false; }
  }

  Future<void> mute() async {
    muted = true;
    _captureBuffer.clear();
    await _captureSub?.cancel();
    _captureSub = null;
    try { await _recorder.stop(); } catch (_) {}
  }

  Future<void> _handlePacket(List<int> data) async {
    if (!sessionActive || roomId == null || data.length < 17) return;
    final packet = Uint8List.fromList(data);
    if (packet[0] != 0x4C || packet[1] != 0x46 || packet[2] != 0x53 || packet[3] != 0x31) return;
    final payload = packet.sublist(8);
    final pcm = decodePcm16(payload);
    if (pcm.isEmpty) return;
    _playbackQueue.add(pcm16ToWav(pcm));
    // Bound latency/memory if the network falls behind playback.
    if (_playbackQueue.length > 25) {
      _playbackQueue.removeRange(0, _playbackQueue.length - 25);
    }
    await _pumpVoicePlayback();
  }

  Future<void> _pumpVoicePlayback() async {
    if (!sessionActive || _playingVoicePacket || _playbackQueue.isEmpty) return;
    _playingVoicePacket = true;
    final wav = _playbackQueue.removeAt(0);
    try {
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'), mode: PlayerMode.mediaPlayer);
    } catch (_) {
      _playingVoicePacket = false;
      if (sessionActive) {
        // Continue with the next queued packet instead of killing the voice path.
        await _pumpVoicePlayback();
      }
    }
  }

  Future<void> dispose() async {
    await detach();
    _playbackQueue.clear();
    await _playerCompleteSub?.cancel();
    _playerCompleteSub = null;
    await _player.dispose();
    await _recorder.dispose();
  }
}
