import 'package:flutter/foundation.dart';

/// Represents a compiled regex pattern and its replacement metadata.
class CompiledPattern {
  final RegExp regex;
  final String template;
  final Map<int, String> roles; // 0-based capture group index -> role name
  final int priority;
  final int index; // Stable tie-breaker matching catalog original ordering

  const CompiledPattern({
    required this.regex,
    required this.template,
    required this.roles,
    this.priority = 0,
    this.index = 0,
  });
}

/// Dynamic regex pattern resolver for Let's Fly.
/// Translates server-generated Arabic game actions, announcements, and activity
/// strings into English while preserving player usernames, numeric scores, dice rolls,
/// and punctuation.
class PatternResolver {
  final List<CompiledPattern> _patterns;
  final String Function(String key, {Map<String, dynamic>? args}) _translate;

  PatternResolver({
    required List<CompiledPattern> patterns,
    required String Function(String key, {Map<String, dynamic>? args}) translate,
  })  : _patterns = patterns,
        _translate = translate;

  /// Sanitizes regex patterns for ECMAScript/Dart RegExp compliance with unicode: true.
  /// Replaces non-syntax identity escapes (\ , \-) with unescaped characters.
  static String sanitizeRegex(String pattern) {
    return pattern.replaceAll(r'\ ', ' ').replaceAll(r'\-', '-');
  }

  /// Decodes \uXXXX unicode escapes into actual unicode characters.
  static String decodeUnicode(String patternStr) {
    return patternStr.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
      final code = int.parse(m.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
  }

  /// Calculates specificity priority for a regex pattern matching Python client's _pat_priority.
  /// Fixed literal text gives higher score; capture groups/branches penalize.
  static int calculatePriority(String patternStr) {
    final decoded = decodeUnicode(patternStr);
    var i = 0;
    final n = decoded.length;
    var literalCount = 0.0;
    var groupPenalty = 0.0;

    while (i < n) {
      final c = decoded[i];
      String? atomType;

      if (c == '^' || c == r'$') {
        atomType = 'anchor';
        i++;
      } else if (c == '\\') {
        if (i + 1 < n) {
          final c2 = decoded[i + 1];
          if (c2 == 'd' || c2 == 'D' || c2 == 's' || c2 == 'S' || c2 == 'w' || c2 == 'W') {
            atomType = 'in';
            i += 2;
          } else {
            atomType = 'literal';
            i += 2;
          }
        } else {
          atomType = 'literal';
          i++;
        }
      } else if (c == '[') {
        var j = i + 1;
        while (j < n && decoded[j] != ']') {
          if (decoded[j] == '\\') {
            j += 2;
          } else {
            j++;
          }
        }
        if (j < n) j++;
        atomType = 'in';
        i = j;
      } else if (c == '(') {
        groupPenalty += 1.0;
        i++;
        continue;
      } else if (c == ')') {
        i++;
        continue;
      } else if (c == '|') {
        groupPenalty += 0.5;
        i++;
        continue;
      } else {
        atomType = 'literal';
        i++;
      }

      var isQuantified = false;
      while (i < n && (decoded[i] == '*' || decoded[i] == '+' || decoded[i] == '?' || decoded[i] == '{')) {
        isQuantified = true;
        if (decoded[i] == '{') {
          while (i < n && decoded[i] != '}') {
            i++;
          }
          if (i < n) i++;
        } else {
          i++;
        }
      }

      if (!isQuantified) {
        if (atomType == 'literal') {
          literalCount += 1.0;
        } else if (atomType == 'in') {
          literalCount += 0.25;
        }
      }
    }

    return (literalCount * 100 - groupPenalty).toInt();
  }

  /// Compiles raw JSON patterns and sorts them by specificity priority.
  factory PatternResolver.fromRaw({
    required List<dynamic> rawPatterns,
    required String Function(String key, {Map<String, dynamic>? args}) translate,
  }) {
    final compiled = <CompiledPattern>[];

    for (var patIdx = 0; patIdx < rawPatterns.length; patIdx++) {
      final item = rawPatterns[patIdx];
      if (item is! Map<String, dynamic>) continue;
      final patStr = item['pattern']?.toString() ?? '';
      final template = item['template']?.toString() ?? '';
      final rawRoles = item['roles'];

      if (patStr.isEmpty || template.isEmpty) continue;

      final rolesMap = <int, String>{};
      if (rawRoles is List) {
        for (var i = 0; i < rawRoles.length; i++) {
          rolesMap[i] = rawRoles[i]?.toString() ?? 'text';
        }
      } else if (rawRoles is Map) {
        rawRoles.forEach((k, v) {
          final idx = int.tryParse(k.toString());
          if (idx != null) {
            rolesMap[idx] = v?.toString() ?? 'text';
          }
        });
      }

      final priority = calculatePriority(patStr);
      final sanitized = sanitizeRegex(patStr);

      try {
        final reg = RegExp(sanitized, unicode: true);
        compiled.add(CompiledPattern(
          regex: reg,
          template: template,
          roles: rolesMap,
          priority: priority,
          index: patIdx,
        ));
      } catch (e) {
        debugPrint('[PatternResolver] Failed to compile regex: $patStr, error: $e');
      }
    }

    // Stable sort: descending priority, preserving catalog index on ties
    compiled.sort((a, b) {
      final cmp = b.priority.compareTo(a.priority);
      if (cmp != 0) return cmp;
      return a.index.compareTo(b.index);
    });

    return PatternResolver(patterns: compiled, translate: translate);
  }

  List<CompiledPattern> get patterns => _patterns;

  /// Resolves and translates a dynamic server message into the active language.
  String resolve(String rawMessage, String activeLang) {
    if (rawMessage.isEmpty) return rawMessage;

    final s = rawMessage;
    final leading = s.substring(0, s.length - s.trimLeft().length);
    final trailing = s.substring(s.trimRight().length);
    final stripped = s.trim();

    // 1. Dynamic regex template pattern matching on whole string
    for (final cp in _patterns) {
      RegExpMatch? m = cp.regex.firstMatch(stripped);
      if (m == null && stripped.endsWith('.')) {
        m = cp.regex.firstMatch(stripped.substring(0, stripped.length - 1).trimRight());
      }

      if (m != null) {
        final translatedArgs = <String>[];
        for (var i = 0; i < m.groupCount; i++) {
          final val = m.group(i + 1) ?? '';
          final role = cp.roles[i] ?? 'text';
          translatedArgs.add(_resolveRole(val, role, activeLang));
        }

        try {
          // Format template placeholders safely without cross-replacement collision
          final out = cp.template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
            final idx = int.tryParse(match.group(1) ?? '');
            if (idx != null && idx >= 0 && idx < translatedArgs.length) {
              return translatedArgs[idx];
            }
            return match.group(0) ?? '';
          });
          return '$leading$out$trailing';
        } catch (_) {
          continue;
        }
      }
    }

    // 2. Multi-sentence splitting (fallback for concatenated statements)
    if (stripped.contains('. ') || stripped.contains('! ') || stripped.contains('؟ ') || stripped.contains('? ')) {
      final parts = stripped.split(RegExp(r'(?<=[.!?؟])\s+'));
      var changed = false;
      final translatedParts = <String>[];
      for (final p in parts) {
        final pClean = p.trim();
        final t = _translate(pClean);
        if (t != pClean) {
          changed = true;
          translatedParts.add(t);
        } else {
          final pTest = (!pClean.endsWith('.') && !pClean.endsWith('!') && !pClean.endsWith('؟') && !pClean.endsWith('?'))
              ? '$pClean.'
              : pClean;
          final t2 = _translate(pTest);
          if (t2 != pTest) {
            changed = true;
            translatedParts.add(t2);
          } else {
            translatedParts.add(p);
          }
        }
      }
      if (changed) {
        return '$leading${translatedParts.join(' ')}$trailing';
      }
    }

    // 3. Fallback: Arabic comma lists (matches client/localization.py line 438-444)
    if (stripped.contains('، ')) {
      final parts = stripped.split('، ');
      final transParts = parts.map((p) => _translate(p.trim())).toList();
      return '$leading${transParts.join(', ')}$trailing';
    }

    return s;
  }

  /// Resolves an extracted argument based on its assigned semantic role.
  String _resolveRole(String val, String role, String activeLang) {
    if (role == 'pts') {
      return val.startsWith('\u0646') ? 'points' : 'units';
    } else if (role == 'score_list') {
      return val.replaceAll(RegExp(r'(?<!\w)نقاط(?!\w)'), 'points').replaceAll('، ', ', ');
    } else if (role == 'set_list') {
      return val.replaceAll('، ', ', ');
    } else if (const {
      'game', 'title', 'rules', 'color', 'combo', 'tile', 'side',
      'card', 'card_list', 'status', 'sub'
    }.contains(role)) {
      var translated = _translate(val);
      if (role == 'sub' && activeLang == 'en') {
        translated = translated.replaceAll(RegExp(r'(?<!\w)النتائج:(?!\w)'), 'Scores:');
        translated = translated.replaceAll(RegExp(r'(?<!\w)المجموعات:(?!\w)'), 'Groups:');
        translated = translated.replaceAll(RegExp(r'(?<!\w)الدور التالي:(?!\w)'), 'Next turn:');
        translated = translated.replaceAll(RegExp(r'(?<!\w)نقاط(?=\.|،|,|$)'), 'points');
        translated = translated.replaceAll('، ', ', ');
      }
      return translated;
    } else {
      // user, num, text, dice are runtime dynamic data and MUST remain untouched!
      return val;
    }
  }
}
