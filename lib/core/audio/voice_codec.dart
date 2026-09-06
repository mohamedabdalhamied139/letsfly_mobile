import 'dart:typed_data';

const _magic = <int>[0x4C, 0x46, 0x56, 0x31]; // LFV1
const _indexTable = <int>[-1,-1,-1,-1,2,4,6,8];
const _stepTable = <int>[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4877,5372,5894,6484,7132,7846,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29801,32767];

int _clamp(int value, int min, int max) => value < min ? min : value > max ? max : value;

(int code, int predictor, int index) _encodeNibble(int sample, int predictor, int index) {
  final step = _stepTable[index];
  var diff = sample - predictor;
  final sign = diff < 0 ? 8 : 0;
  if (diff < 0) diff = -diff;
  var delta = 0;
  var temp = step;
  if (diff >= temp) { delta |= 4; diff -= temp; }
  temp >>= 1;
  if (diff >= temp) { delta |= 2; diff -= temp; }
  temp >>= 1;
  if (diff >= temp) delta |= 1;
  var diffq = step >> 3;
  if ((delta & 4) != 0) diffq += step;
  if ((delta & 2) != 0) diffq += step >> 1;
  if ((delta & 1) != 0) diffq += step >> 2;
  predictor += sign != 0 ? -diffq : diffq;
  predictor = _clamp(predictor, -32768, 32767);
  index = _clamp(index + _indexTable[delta], 0, 88);
  return (delta | sign, predictor, index);
}

(int predictor, int index) _decodeNibble(int code, int predictor, int index) {
  final step = _stepTable[index];
  var diffq = step >> 3;
  if ((code & 4) != 0) diffq += step;
  if ((code & 2) != 0) diffq += step >> 1;
  if ((code & 1) != 0) diffq += step >> 2;
  predictor += (code & 8) != 0 ? -diffq : diffq;
  predictor = _clamp(predictor, -32768, 32767);
  index = _clamp(index + _indexTable[code & 7], 0, 88);
  return (predictor, index);
}

Uint8List encodePcm16(Uint8List pcm) {
  final count = pcm.length ~/ 2;
  if (count <= 0) return Uint8List(0);
  final bd = ByteData.sublistView(pcm);
  var predictor = bd.getInt16(0, Endian.little);
  var index = 0;
  final out = BytesBuilder(copy: false);
  out.add(_magic);
  final header = ByteData(5)..setInt16(0, predictor, Endian.little)..setUint8(2, index)..setUint16(3, count, Endian.little);
  out.add(header.buffer.asUint8List());
  var pending = -1;
  for (var i = 1; i < count; i++) {
    final sample = bd.getInt16(i * 2, Endian.little);
    final r = _encodeNibble(sample, predictor, index);
    predictor = r.$2; index = r.$3;
    if (pending < 0) pending = r.$1; else { out.addByte(pending | (r.$1 << 4)); pending = -1; }
  }
  if (pending >= 0) out.addByte(pending);
  return out.takeBytes();
}

Uint8List decodePcm16(Uint8List packet) {
  if (packet.length < 9 || packet[0] != _magic[0] || packet[1] != _magic[1] || packet[2] != _magic[2] || packet[3] != _magic[3]) return Uint8List(0);
  final bd = ByteData.sublistView(packet);
  var predictor = bd.getInt16(4, Endian.little);
  var index = bd.getUint8(6);
  final count = bd.getUint16(7, Endian.little);
  if (count < 1 || count > 4096 || index > 88) return Uint8List(0);
  final out = ByteData(count * 2);
  out.setInt16(0, predictor, Endian.little);
  var pos = 1;
  for (var i = 9; i < packet.length && pos < count; i++) {
    final b = packet[i];
    for (final code in [b & 0x0F, (b >> 4) & 0x0F]) {
      if (pos >= count) break;
      final r = _decodeNibble(code, predictor, index);
      predictor = r.$1; index = r.$2;
      out.setInt16(pos * 2, predictor, Endian.little);
      pos++;
    }
  }
  return pos == count ? out.buffer.asUint8List() : Uint8List(0);
}

Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final bytes = ByteData(44 + pcm.length);
  void ascii(int offset, String text) { for (var i = 0; i < text.length; i++) bytes.setUint8(offset + i, text.codeUnitAt(i)); }
  ascii(0, 'RIFF'); bytes.setUint32(4, 36 + pcm.length, Endian.little); ascii(8, 'WAVE'); ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); bytes.setUint16(20, 1, Endian.little); bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little); bytes.setUint32(28, sampleRate * channels * 2, Endian.little);
  bytes.setUint16(32, channels * 2, Endian.little); bytes.setUint16(34, 16, Endian.little); ascii(36, 'data'); bytes.setUint32(40, pcm.length, Endian.little);
  bytes.buffer.asUint8List().setRange(44, 44 + pcm.length, pcm);
  return bytes.buffer.asUint8List();
}
