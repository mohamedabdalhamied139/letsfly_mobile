// Contract-level checks for the Windows-baseline table behavior.
// Runtime execution requires Flutter; this file documents the acceptance contract.
// 1. Every game exposes the same table context-menu order as Windows.
// 2. Every table exposes player names with their current server score.
// 3. Tennis directional touch gestures are two-finger only:
//    left/right = position, up = serve/hit, down = activity log.
// 4. One-finger directional swipes never invoke gameplay actions.
