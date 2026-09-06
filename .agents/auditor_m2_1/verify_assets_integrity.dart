// Forensic Auditor Asset Integrity Verification
import 'dart:io';

void main() {
  print('======================================================================');
  print('        FORENSIC AUDIT: SOUND ASSET INTEGRITY VERIFICATION');
  print('======================================================================\n');

  final dartFiles = [
    'lib/core/audio/sound_engine.dart',
    'lib/core/audio/tennis_sound_engine.dart',
    'lib/core/audio/sound_cues.dart',
  ];

  final regExp = RegExp(r"['""]audio\/[^'""]+\.wav['""]");
  final Set<String> registeredPaths = {};

  for (final path in dartFiles) {
    final f = File(path);
    if (!f.existsSync()) {
      print('[WARN] File not found: $path');
      continue;
    }
    final content = f.readAsStringSync();
    final matches = regExp.allMatches(content);
    for (final m in matches) {
      final matched = m.group(0)!;
      final cleanPath = matched.substring(1, matched.length - 1);
      registeredPaths.add(cleanPath);
    }
  }

  print('Discovered ${registeredPaths.length} unique sound asset references.');

  final List<String> missing = [];
  final List<String> present = [];

  for (final assetRel in registeredPaths) {
    final fullFile = File('assets/$assetRel');
    if (!fullFile.existsSync()) {
      missing.add(assetRel);
    } else {
      present.add(assetRel);
    }
  }

  print('Existing asset files verified: ${present.length}');
  print('Missing asset files: ${missing.length}');

  if (missing.isNotEmpty) {
    print('\n[FAIL] Missing audio asset files:');
    for (final m in missing) {
      print('  - assets/$m');
    }
    exit(1);
  } else {
    print('\n[PASS] All ${registeredPaths.length} registered sound assets empirically exist on disk!');
  }
}
