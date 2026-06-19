---
status: testing
phase: 07-carhud-loop-timer-difficulty-scaling
source: [07-VERIFICATION.md]
started: 2026-06-19T00:00:00Z
updated: 2026-06-19T00:00:00Z
---

## Current Test

number: 1
name: ENGINE indicator fires on all clients during fire element combat
expected: |
  In a 2-player session, when a fire-element player fires a burst or a fire proc triggers,
  the ENGINE 🔥 OVERHEAT indicator lights up on BOTH clients' CarHUD panels simultaneously.
awaiting: user response

## Tests

### 1. ENGINE indicator fires on all clients during fire element combat
expected: In a 2-player (host + client) session, select fire element. Fire burst or wait for proc. The ENGINE 🔥 OVERHEAT CarHUD indicator should light up on BOTH screens within the same frame.
result: [pending]

### 2. Loop 2 is visibly harder — more enemies with more HP
expected: After triggering `GameState.start_next_loop()` (or via Phase 8 boss defeat), the initial enemy count increases (~12 vs 8) and enemies take noticeably more hits to kill (~1.25x HP).
result: [pending]

### 3. Revive gate end-to-end — second revive blocked, resets on next loop
expected: Player A downs Player B. Player B gets revived (1st use). Player B goes down again. Player A attempts revive → should fail silently (B stays downed). On next loop start (start_next_loop()), revive works again.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
