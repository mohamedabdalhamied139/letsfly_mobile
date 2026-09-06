/// Zero-dependency test runner engine & assertions for hermetic E2E tests
library letsfly_test_framework;

import 'dart:async';

class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);
  @override
  String toString() => 'TestFailure: $message';
}

class TestCase {
  final String suiteName;
  final String name;
  final FutureOr<void> Function() body;
  bool passed = false;
  String? errorMessage;
  StackTrace? stackTrace;
  Duration duration = Duration.zero;

  TestCase(this.suiteName, this.name, this.body);
}

class TestSuite {
  final String name;
  final List<TestCase> tests = [];
  FutureOr<void> Function()? setUpFn;
  FutureOr<void> Function()? tearDownFn;

  TestSuite(this.name);
}

class TestRegistry {
  static final List<TestSuite> suites = [];
  static TestSuite? _currentSuite;

  static void describe(String suiteName, void Function() body) {
    final suite = TestSuite(suiteName);
    suites.add(suite);
    _currentSuite = suite;
    body();
    _currentSuite = null;
  }

  static void addTest(String name, FutureOr<void> Function() body) {
    if (_currentSuite == null) {
      describe('Default Suite', () {
        addTest(name, body);
      });
      return;
    }
    _currentSuite!.tests.add(TestCase(_currentSuite!.name, name, body));
  }

  static void setSetUp(FutureOr<void> Function() fn) {
    if (_currentSuite != null) {
      _currentSuite!.setUpFn = fn;
    }
  }

  static void setTearDown(FutureOr<void> Function() fn) {
    if (_currentSuite != null) {
      _currentSuite!.tearDownFn = fn;
    }
  }

  static void clear() {
    suites.clear();
    _currentSuite = null;
  }
}

// Global DSL functions
void describe(String suiteName, void Function() body) => TestRegistry.describe(suiteName, body);
void test(String testName, FutureOr<void> Function() body) => TestRegistry.addTest(testName, body);
void setUp(FutureOr<void> Function() fn) => TestRegistry.setSetUp(fn);
void tearDown(FutureOr<void> Function() fn) => TestRegistry.setTearDown(fn);

// Assertions
void expect(dynamic actual, dynamic expected, {String? reason}) {
  if (expected is _Matcher) {
    if (!expected.matches(actual)) {
      throw TestFailure(reason ?? expected.mismatchDescription(actual));
    }
  } else {
    if (actual != expected) {
      throw TestFailure(reason ?? 'Expected: $expected\n  Actual: $actual');
    }
  }
}

abstract class _Matcher {
  bool matches(dynamic actual);
  String mismatchDescription(dynamic actual);
}

class _EqualsMatcher extends _Matcher {
  final dynamic expected;
  _EqualsMatcher(this.expected);

  @override
  bool matches(dynamic actual) {
    if (expected is List && actual is List) {
      if (expected.length != actual.length) return false;
      for (int i = 0; i < expected.length; i++) {
        if (expected[i] != actual[i]) return false;
      }
      return true;
    }
    if (expected is Map && actual is Map) {
      if (expected.length != actual.length) return false;
      for (final key in expected.keys) {
        if (!actual.containsKey(key) || actual[key] != expected[key]) return false;
      }
      return true;
    }
    return actual == expected;
  }

  @override
  String mismatchDescription(dynamic actual) => 'Expected equals $expected but got $actual';
}

class _TrueMatcher extends _Matcher {
  @override
  bool matches(dynamic actual) => actual == true;
  @override
  String mismatchDescription(dynamic actual) => 'Expected true but got $actual';
}

class _FalseMatcher extends _Matcher {
  @override
  bool matches(dynamic actual) => actual == false;
  @override
  String mismatchDescription(dynamic actual) => 'Expected false but got $actual';
}

class _NullMatcher extends _Matcher {
  @override
  bool matches(dynamic actual) => actual == null;
  @override
  String mismatchDescription(dynamic actual) => 'Expected null but got $actual';
}

class _NotNullMatcher extends _Matcher {
  @override
  bool matches(dynamic actual) => actual != null;
  @override
  String mismatchDescription(dynamic actual) => 'Expected not null but got null';
}

class _ContainsMatcher extends _Matcher {
  final dynamic element;
  _ContainsMatcher(this.element);

  @override
  bool matches(dynamic actual) {
    if (actual is String) {
      return actual.contains(element.toString());
    }
    if (actual is Iterable) {
      return actual.contains(element);
    }
    if (actual is Map) {
      return actual.containsKey(element);
    }
    return false;
  }

  @override
  String mismatchDescription(dynamic actual) => 'Expected $actual to contain $element';
}

class _GreaterThanMatcher extends _Matcher {
  final num value;
  _GreaterThanMatcher(this.value);
  @override
  bool matches(dynamic actual) => actual is num && actual > value;
  @override
  String mismatchDescription(dynamic actual) => 'Expected > $value but got $actual';
}

class _GreaterOrEqualMatcher extends _Matcher {
  final num value;
  _GreaterOrEqualMatcher(this.value);
  @override
  bool matches(dynamic actual) => actual is num && actual >= value;
  @override
  String mismatchDescription(dynamic actual) => 'Expected >= $value but got $actual';
}

class _HasLengthMatcher extends _Matcher {
  final int length;
  _HasLengthMatcher(this.length);
  @override
  bool matches(dynamic actual) {
    if (actual is String) return actual.length == length;
    if (actual is Iterable) return actual.length == length;
    if (actual is Map) return actual.length == length;
    return false;
  }
  @override
  String mismatchDescription(dynamic actual) => 'Expected length $length but got ${actual?.length}';
}

class _ThrowsMatcher extends _Matcher {
  @override
  bool matches(dynamic actual) => true; // Handled in throwsA
  @override
  String mismatchDescription(dynamic actual) => 'Expected exception';
}

_Matcher equals(dynamic val) => _EqualsMatcher(val);
_Matcher isTrue = _TrueMatcher();
_Matcher isFalse = _FalseMatcher();
_Matcher isNull = _NullMatcher();
_Matcher isNotNull = _NotNullMatcher();
_Matcher contains(dynamic element) => _ContainsMatcher(element);
_Matcher greaterThan(num val) => _GreaterThanMatcher(val);
_Matcher greaterThanOrEqualTo(num val) => _GreaterOrEqualMatcher(val);
_Matcher hasLength(int len) => _HasLengthMatcher(len);
_Matcher throwsException = _ThrowsMatcher();

Future<void> expectThrows(FutureOr<void> Function() action, {String? reason}) async {
  bool threw = false;
  try {
    await action();
  } catch (_) {
    threw = true;
  }
  if (!threw) {
    throw TestFailure(reason ?? 'Expected exception but none was thrown.');
  }
}

class GestureRecognizerEngine {
  final dynamic handler;
  double _startX = 0;
  double _startY = 0;

  GestureRecognizerEngine({this.handler});

  void onDragStart(double x, double y) {
    _startX = x;
    _startY = y;
  }

  void onDragEnd(double x, double y) {
    final dx = x - _startX;
    final dy = y - _startY;
    if (dx.abs() >= dy.abs()) {
      if (dx > 48) {
        handler?.onSwipeRight?.call();
      } else if (dx < -48) {
        handler?.onSwipeLeft?.call();
      }
    } else {
      if (dy > 48) {
        handler?.onSwipeDown?.call();
      } else if (dy < -48) {
        handler?.onSwipeUp?.call();
      }
    }
  }
}

