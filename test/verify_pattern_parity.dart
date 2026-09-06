/// Standalone Dart verification runner for localization and pattern parity.
/// Validates that all 435 patterns in patterns.json compile in Dart RegExp,
/// adhere to priority specificity sorting, and accurately resolve dynamic action strings.
library verify_pattern_parity;

import 'dart:convert';
import 'dart:io';

String sanitizeRegex(String pattern) {
  return pattern.replaceAll(r'\ ', ' ').replaceAll(r'\-', '-');
}

String decodeUnicode(String patternStr) {
  return patternStr.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
    final code = int.parse(m.group(1)!, radix: 16);
    return String.fromCharCode(code);
  });
}

int calculatePriority(String patternStr) {
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

void main() {
  final patternsFile = File('assets/locales/patterns.json');
  final enFile = File('assets/locales/en.json');

  if (!patternsFile.existsSync() || !enFile.existsSync()) {
    stderr.writeln('Missing asset files');
    exit(2);
  }

  final patternsRaw = jsonDecode(patternsFile.readAsStringSync()) as List<dynamic>;
  final enCatalog = (jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v.toString()));

  String translate(String key) {
    if (enCatalog.containsKey(key)) return enCatalog[key]!;
    final stripped = key.trim();
    if (enCatalog.containsKey(stripped)) return enCatalog[stripped]!;
    return key;
  }

  int compiledCount = 0;
  int failedCount = 0;
  final compiledList = <Map<String, dynamic>>[];

  for (var patIdx = 0; patIdx < patternsRaw.length; patIdx++) {
    final item = patternsRaw[patIdx];
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

    final sanitized = sanitizeRegex(patStr);
    final priority = calculatePriority(patStr);

    try {
      final reg = RegExp(sanitized, unicode: true);
      compiledCount++;
      compiledList.add({
        'regex': reg,
        'template': template,
        'roles': rolesMap,
        'priority': priority,
        'index': patIdx,
      });
    } catch (e) {
      failedCount++;
      stderr.writeln('Failed to compile: $patStr -> $e');
    }
  }

  // Sort descending by priority, breaking ties with original catalog index
  compiledList.sort((a, b) {
    final cmp = (b['priority'] as int).compareTo(a['priority'] as int);
    if (cmp != 0) return cmp;
    return (a['index'] as int).compareTo(b['index'] as int);
  });

  String resolvePattern(String raw) {
    final stripped = raw.trim();
    final leading = raw.substring(0, raw.length - raw.trimLeft().length);
    final trailing = raw.substring(raw.trimRight().length);

    // 1. Direct catalog lookup
    if (enCatalog.containsKey(raw)) return enCatalog[raw]!;
    if (enCatalog.containsKey(stripped)) {
      return '$leading${enCatalog[stripped]!}$trailing';
    }

    // 2. Pattern matching
    for (final cp in compiledList) {
      final reg = cp['regex'] as RegExp;
      final template = cp['template'] as String;
      final roles = cp['roles'] as Map<int, String>;

      var m = reg.firstMatch(stripped);
      if (m == null && stripped.endsWith('.')) {
        m = reg.firstMatch(stripped.substring(0, stripped.length - 1).trimRight());
      }

      if (m != null) {
        final args = <String>[];
        for (var i = 0; i < m.groupCount; i++) {
          final val = m.group(i + 1) ?? '';
          final role = roles[i] ?? 'text';
          if (role == 'pts') {
            args.add(val.startsWith('\u0646') ? 'points' : 'units');
          } else if (role == 'score_list') {
            args.add(val.replaceAll(RegExp(r'(?<!\w)نقاط(?!\w)'), 'points').replaceAll('، ', ', '));
          } else if (const {'game', 'title', 'rules', 'color', 'combo', 'tile', 'side', 'card', 'card_list', 'status', 'sub'}.contains(role)) {
            args.add(resolvePattern(val));
          } else {
            args.add(val);
          }
        }

        try {
          final out = template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
            final idx = int.tryParse(match.group(1) ?? '');
            if (idx != null && idx >= 0 && idx < args.length) {
              return args[idx];
            }
            return match.group(0) ?? '';
          });
          return '$leading$out$trailing';
        } catch (_) {
          continue;
        }
      }
    }

    return raw;
  }

  final testCases = [
    {'input': 'أحمر 7', 'expected': 'Red 7'},
    {'input': 'أصفر 0', 'expected': 'Yellow 0'},
    {'input': 'أزرق سحب 2', 'expected': 'Blue Draw Two'},
    {'input': 'أخضر تخطي', 'expected': 'Green Skip'},
    {'input': 'أحمر عكس الاتجاه', 'expected': 'Red Reverse'},
    {'input': 'تبديل اللون وسحب 4', 'expected': 'Wild Draw Four'},
    {'input': 'تبديل اللون', 'expected': 'Wild'},
    {'input': 'أحمد لعب أحمر 7', 'expected': 'أحمد played Red 7'},
    {'input': 'رمى Sarah 6.', 'expected': 'Sarah rolled a 6.'},
    {'input': 'Mido (متصل)', 'expected': 'Mido (Online)'},
    {'input': 'أحمد: 50 نقاط', 'expected': 'أحمد: 50 points'},
  ];

  int passedCases = 0;
  final caseResults = <Map<String, dynamic>>[];
  for (final tc in testCases) {
    final input = tc['input']!;
    final expected = tc['expected']!;
    final actual = resolvePattern(input);
    final passed = actual == expected;
    if (passed) passedCases++;
    caseResults.add({
      'input': input,
      'expected': expected,
      'actual': actual,
      'passed': passed,
    });
  }

  final summary = {
    'total_patterns': patternsRaw.length,
    'compiled_patterns': compiledCount,
    'failed_patterns': failedCount,
    'total_cases': testCases.length,
    'passed_cases': passedCases,
    'case_results': caseResults,
  };

  print('__DART_VERIFY_JSON_START__');
  print(jsonEncode(summary));
  print('__DART_VERIFY_JSON_END__');

  if (failedCount > 0 || passedCases != testCases.length) {
    exit(1);
  } else {
    exit(0);
  }
}
