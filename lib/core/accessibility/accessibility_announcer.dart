import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';

/// Announcement priority level for screen readers.
enum AnnouncePriority {
  /// Polite: Screen reader waits until current announcement finishes.
  polite,

  /// Assertive: Screen reader interrupts current speech immediately.
  assertive,
}

/// Abstract contract for accessibility announcements.
abstract class AccessibilityAnnouncer {
  Future<void> announce(String message, {AnnouncePriority priority = AnnouncePriority.polite});
}

/// Callback delegate for platform announcement execution or test capture
typedef AnnouncePlatformDelegate = Future<void> Function(
  String message, {
  required bool assertive,
  required bool isRtl,
});

/// Production implementation of AccessibilityAnnouncer utilizing SemanticsService.
class StandardAccessibilityAnnouncer implements AccessibilityAnnouncer {
  final AnnouncePlatformDelegate? delegate;
  String _lastAnnouncement = '';
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);

  StandardAccessibilityAnnouncer({this.delegate});

  @override
  Future<void> announce(String message, {AnnouncePriority priority = AnnouncePriority.polite}) async {
    final clean = message.trim();
    if (clean.isEmpty) return;

    // Deduplicate repeated identical messages within 300ms to avoid audio stutter
    final now = DateTime.now();
    if (clean == _lastAnnouncement && now.difference(_lastTime).inMilliseconds < 300) {
      return;
    }
    _lastAnnouncement = clean;
    _lastTime = now;

    final direction = _detectDirection(clean);
    final assertive = priority == AnnouncePriority.assertive;
    final isRtl = direction == TextDirection.rtl;

    if (delegate != null) {
      await delegate!(clean, assertive: assertive, isRtl: isRtl);
      return;
    }

    try {
      SemanticsService.announce(
        clean,
        direction,
        assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
      );
    } catch (_) {
      // Fallback in test environments where SemanticsService might not have a renderer
      debugPrint('[AccessibilityAnnouncer] ($priority): $clean');
    }
  }

  TextDirection _detectDirection(String text) {
    // Check if contains Arabic characters
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }
}
