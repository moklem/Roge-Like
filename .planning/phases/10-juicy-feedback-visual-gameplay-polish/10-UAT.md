---
status: testing
phase: 10-juicy-feedback-visual-gameplay-polish
source: [10-12-SUMMARY.md]
started: 2026-07-13
updated: 2026-07-13
---

## Current Test

number: 1
name: Settings panel — audible and visual response
expected: |
  Music and SFX sliders each attenuate their own channel independently.
  Shake cycle OFF/LOW/NORMAL visibly changes shake intensity.
awaiting: user response

## Tests

### 1. Settings panel — audible/visual response
expected: |
  On the Main Menu, open Settings.
  - Drag the Music slider → music volume changes, SFX unaffected.
  - Drag the SFX slider → sound effects change, music unaffected.
  - Cycle SCREEN SHAKE OFF / LOW / NORMAL → shake intensity visibly changes in-game.
  This is the confirmation deliberately deferred from Plans 10-02 and 10-05.
result: [pending]

### 2. Swarm readability + capped shake (SYS-02)
expected: |
  Trigger heavy simultaneous fire against a dense enemy group.
  On BOTH host and client:
  - Damage numbers stay readable — they aggregate on rapid same-target hits and
    do not stack unboundedly (fixed 24-slot pool).
  - Screen shake stays capped — no compounding/nauseating shake.
  Then set shake to OFF: shake stops entirely, but hit-flashes, particles and
  hit-stop still play (D-11 — shake control governs shake ONLY).
result: [pending]

### 3. Every juice moment is team-visible
expected: |
  Confirm each of these is visible on EVERY peer's screen, not just the host:
  - Enemy hit numbers, hit-flash, HP chip-away, death burst
  - Element hit VFX + burn/slow status tint (this was the ABIL-01 bug — was host-only, now replicated)
  - XP orb magnetism + dart-to-bar with arrival-gated bar increase
  - Card overlay pop-in (both level-up pick AND sub-room weapon choice)
  - Level-up burst
  - Speedster dash afterimage trail
  - Tank aura ring pulse
  - Engineer heal sparkle + drone deploy burst
  - Downed collapse, team-visible revive progress ring, revive success burst
  - Big-hit team broadcast
  - Evolution transform — CRITICAL: confirm NO input freeze and NO camera lock,
    for the transforming player AND for teammates (D-14: must not become a cutscene)
result: [pending]

### 4. Node-leak soak (SYS-03) + frame rate (SYS-02)
expected: |
  Run effects continuously for several minutes.
  Open the remote scene-tree inspector on BOTH host and client.
  - Zero orphaned Tween / CPUParticles2D / Label nodes accumulating
  - No visible frame-rate degradation over time
  Every burst has a backstop cleanup timer (lifetime + 0.5s) in addition to its
  own finished-signal cleanup.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
