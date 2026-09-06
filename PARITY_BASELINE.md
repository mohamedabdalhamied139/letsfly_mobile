# Let's Fly Mobile — Windows Parity Baseline

Windows `LetsFly_v2_fixed` is the authoritative functional baseline. Mobile is a platform port and must preserve the same server contracts, room lifecycle, game registry, settings schema, social operations, activity categories, and event semantics.

## Explicit invariant

`lib/core/accessibility/gesture_controller.dart` is a protected subsystem. It is not replaced, redesigned, or reinterpreted as part of Windows/Mobile parity work.

## Server contract

The mobile client uses the same production REST and WebSocket routes implemented by the Windows baseline/server. Platform differences are limited to UI/input/audio capture APIs.
