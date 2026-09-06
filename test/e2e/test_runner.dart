/// Unified E2E Test Suite Runner for Let's Fly Mobile Client
/// Orchestrates and executes all tests across Tiers 1 through 4 hermetically.
library letsfly_e2e_test_runner;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'harness/test_framework.dart';
import 'harness/client_harness.dart';

// Tier 1 Feature Imports
import 'tier1_features/f01_foundation_test.dart' as f01;
import 'tier1_features/f02_dynamic_localization_test.dart' as f02;
import 'tier1_features/f03_pattern_engine_test.dart' as f03;
import 'tier1_features/f04_sound_engine_test.dart' as f04;
import 'tier1_features/f05_token_storage_test.dart' as f05;
import 'tier1_features/f06_rest_client_test.dart' as f06;
import 'tier1_features/f07_auth_flow_test.dart' as f07;
import 'tier1_features/f08_lobby_ws_test.dart' as f08;
import 'tier1_features/f09_home_lobby_test.dart' as f09;
import 'tier1_features/f10_room_browser_test.dart' as f10;
import 'tier1_features/f11_room_ws_test.dart' as f11;
import 'tier1_features/f12_in_room_chat_test.dart' as f12;
import 'tier1_features/f13_mobile_semantics_test.dart' as f13;
import 'tier1_features/f14_spoken_announcer_test.dart' as f14;
import 'tier1_features/f15_gesture_controller_test.dart' as f15;
import 'tier1_features/f16_table_shell_test.dart' as f16;
import 'tier1_features/f17_uno_state_engine_test.dart' as f17;
import 'tier1_features/f18_dual_axis_hand_test.dart' as f18;
import 'tier1_features/f19_uno_gameplay_actions_test.dart' as f19;
import 'tier1_features/f20_voluntary_draw_guard_test.dart' as f20;
import 'tier1_features/f21_uno_declarations_test.dart' as f21;
import 'tier1_features/f22_round_scoring_bot_sync_test.dart' as f22;

// Tier 2 Boundary Imports
import 'tier2_boundaries/b01_foundation_boundary_test.dart' as b01;
import 'tier2_boundaries/b02_localization_boundary_test.dart' as b02;
import 'tier2_boundaries/b03_pattern_boundary_test.dart' as b03;
import 'tier2_boundaries/b04_sound_boundary_test.dart' as b04;
import 'tier2_boundaries/b05_storage_boundary_test.dart' as b05;
import 'tier2_boundaries/b06_rest_boundary_test.dart' as b06;
import 'tier2_boundaries/b07_auth_boundary_test.dart' as b07;
import 'tier2_boundaries/b08_lobby_ws_boundary_test.dart' as b08;
import 'tier2_boundaries/b09_home_lobby_boundary_test.dart' as b09;
import 'tier2_boundaries/b10_room_browser_boundary_test.dart' as b10;
import 'tier2_boundaries/b11_room_ws_boundary_test.dart' as b11;
import 'tier2_boundaries/b12_chat_boundary_test.dart' as b12;
import 'tier2_boundaries/b13_semantics_boundary_test.dart' as b13;
import 'tier2_boundaries/b14_announcer_boundary_test.dart' as b14;
import 'tier2_boundaries/b15_gesture_boundary_test.dart' as b15;
import 'tier2_boundaries/b16_table_shell_boundary_test.dart' as b16;
import 'tier2_boundaries/b17_state_engine_boundary_test.dart' as b17;
import 'tier2_boundaries/b18_hand_boundary_test.dart' as b18;
import 'tier2_boundaries/b19_gameplay_boundary_test.dart' as b19;
import 'tier2_boundaries/b20_draw_guard_boundary_test.dart' as b20;
import 'tier2_boundaries/b21_declarations_boundary_test.dart' as b21;
import 'tier2_boundaries/b22_scoring_boundary_test.dart' as b22;

// Tier 3 Combinations Import
import 'tier3_interactions/pairwise_interactions_test.dart' as tier3;

// Tier 4 Real-World Scenarios Import
import 'tier4_scenarios/real_world_scenarios_test.dart' as tier4;

Future<void> main() async {
  print('===============================================================');
  print("   LET'S FLY MOBILE CLIENT — UNIFIED E2E TEST RUNNER");
  print('===============================================================\n');

  final harness = LetsFlyTestHarness();
  await harness.setUp();
  print('[HARNESS] Hermetic Mock Backend initialized on:');
  print('          - HTTP: ${harness.httpServer.baseUrl}');
  print('          - WS:   ${harness.wsServer.wsUrl}\n');

  // Register all tiers
  TestRegistry.clear();

  print('[REGISTRATION] Registering Tier 1 Features (F1 - F22)...');
  f01.registerTests(harness);
  f02.registerTests(harness);
  f03.registerTests(harness);
  f04.registerTests(harness);
  f05.registerTests(harness);
  f06.registerTests(harness);
  f07.registerTests(harness);
  f08.registerTests(harness);
  f09.registerTests(harness);
  f10.registerTests(harness);
  f11.registerTests(harness);
  f12.registerTests(harness);
  f13.registerTests(harness);
  f14.registerTests(harness);
  f15.registerTests(harness);
  f16.registerTests(harness);
  f17.registerTests(harness);
  f18.registerTests(harness);
  f19.registerTests(harness);
  f20.registerTests(harness);
  f21.registerTests(harness);
  f22.registerTests(harness);

  print('[REGISTRATION] Registering Tier 2 Boundaries (B1 - B22)...');
  b01.registerTests(harness);
  b02.registerTests(harness);
  b03.registerTests(harness);
  b04.registerTests(harness);
  b05.registerTests(harness);
  b06.registerTests(harness);
  b07.registerTests(harness);
  b08.registerTests(harness);
  b09.registerTests(harness);
  b10.registerTests(harness);
  b11.registerTests(harness);
  b12.registerTests(harness);
  b13.registerTests(harness);
  b14.registerTests(harness);
  b15.registerTests(harness);
  b16.registerTests(harness);
  b17.registerTests(harness);
  b18.registerTests(harness);
  b19.registerTests(harness);
  b20.registerTests(harness);
  b21.registerTests(harness);
  b22.registerTests(harness);

  print('[REGISTRATION] Registering Tier 3 Pairwise Combinations...');
  tier3.registerTests(harness);

  print('[REGISTRATION] Registering Tier 4 Real-World Workload Scenarios...\n');
  tier4.registerTests(harness);

  int totalSuites = TestRegistry.suites.length;
  int totalTests = 0;
  for (final s in TestRegistry.suites) {
    totalTests += s.tests.length;
  }

  print('Total Test Suites: $totalSuites');
  print('Total Test Cases:  $totalTests\n');
  print('---------------------------------------------------------------');
  print('EXECUTING TEST SUITE:');
  print('---------------------------------------------------------------');

  final overallStopwatch = Stopwatch()..start();
  int passedCount = 0;
  int failedCount = 0;
  final failures = <TestCase>[];
  final structuredResults = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'total_suites': totalSuites,
    'total_tests': totalTests,
    'suites': [],
  };

  for (final suite in TestRegistry.suites) {
    int suitePassed = 0;
    int suiteFailed = 0;
    final suiteResults = <String, dynamic>{
      'name': suite.name,
      'tests': [],
    };

    for (final testCase in suite.tests) {
      final testStopwatch = Stopwatch()..start();
      try {
        if (suite.setUpFn != null) await suite.setUpFn!();
        await testCase.body();
        if (suite.tearDownFn != null) await suite.tearDownFn!();

        testStopwatch.stop();
        testCase.passed = true;
        testCase.duration = testStopwatch.elapsed;
        passedCount++;
        suitePassed++;
        suiteResults['tests'].add({
          'name': testCase.name,
          'status': 'PASSED',
          'duration_ms': testStopwatch.elapsedMilliseconds,
        });
      } catch (e, st) {
        testStopwatch.stop();
        testCase.passed = false;
        testCase.errorMessage = e.toString();
        testCase.stackTrace = st;
        testCase.duration = testStopwatch.elapsed;
        failedCount++;
        suiteFailed++;
        failures.add(testCase);
        suiteResults['tests'].add({
          'name': testCase.name,
          'status': 'FAILED',
          'error': e.toString(),
          'duration_ms': testStopwatch.elapsedMilliseconds,
        });
      }
    }

    final suiteStatus = suiteFailed == 0 ? '✓ PASS' : '✗ FAIL';
    print('  [$suiteStatus] ${suite.name} ($suitePassed/${suite.tests.length})');
    structuredResults['suites'].add(suiteResults);
  }

  overallStopwatch.stop();
  final durationMs = overallStopwatch.elapsedMilliseconds;

  print('\n===============================================================');
  print('TEST SUMMARY:');
  print('===============================================================');
  print('Total Tests: $totalTests');
  print('Passed:      $passedCount');
  print('Failed:      $failedCount');
  print('Duration:    ${(durationMs / 1000).toStringAsFixed(2)}s');
  print('Pass Rate:   ${((passedCount / totalTests) * 100).toStringAsFixed(1)}%');

  if (failures.isNotEmpty) {
    print('\nFAILURE DETAILS:');
    print('---------------------------------------------------------------');
    for (final f in failures) {
      print('FAILED: [${f.suiteName}] ${f.name}');
      print('  Error: ${f.errorMessage}');
      if (f.stackTrace != null) {
        print('  Stack: ${f.stackTrace}\n');
      }
    }
  }

  // Teardown harness
  await harness.tearDown();

  structuredResults['passed'] = passedCount;
  structuredResults['failed'] = failedCount;
  structuredResults['duration_ms'] = durationMs;
  structuredResults['success'] = failedCount == 0;

  // Write structured json report
  final jsonFile = File('test_results.json');
  await jsonFile.writeAsString(jsonEncode(structuredResults));
  print('\n[REPORT] Structured report saved to: ${jsonFile.absolute.path}');

  if (failedCount > 0) {
    print('\nRESULT: FAILED (Exit Code 1)');
    exit(1);
  } else {
    print('\nRESULT: SUCCESS (100% Passed, Exit Code 0)');
    exit(0);
  }
}
