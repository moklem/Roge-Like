# Phase 7: CarHUD, Loop Timer & Difficulty Scaling - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-19
**Phase:** 07-carhud-loop-timer-difficulty-scaling
**Areas discussed:** HUD panel architecture, Loop behavior in Phase 7, Difficulty scaling numbers, HUD trigger thresholds

---

## HUD Panel Architecture

| Question | Options | Selected |
|----------|---------|----------|
| Where should the CARIAD side panel live? | CanvasLayer on Game.tscn / Part of PlayerHUD.tscn | CanvasLayer on Game.tscn |
| Panel position | Right side strip / Bottom bar / Top bar | (User clarified in free text: single shared screen for all players, not per-player) |
| RPC broadcast mechanism | RPC on GameEvents.emit_hud / RPC in Game.gd | RPC on GameEvents.emit_hud |
| Indicator fade duration | 2–3 seconds / You decide | 2–3 seconds |
| Indicator visual style | Dark idle + bright lit per indicator color / All same color / You decide | Dark idle, bright lit |
| Emoji in labels | Yes / No | Yes |

**User's key clarification (free text):** "I don't know if you understand this CanvasLayer - the HUD is not per player, there's ONE HUD that the auto player checks" — the CarHUD represents the NPC driver's vehicle dashboard, a single shared panel visible to all players simultaneously.

**Notes:** User confirmed single global panel concept (not per-player). The CARIAD HUD simulates the NPC driver's car reacting to gameplay events.

---

## Loop Behavior in Phase 7

| Question | Options | Selected |
|----------|---------|----------|
| What happens when 15-min timer expires? | Loop restarts / Game over / Timer display only | (User clarified: no timer at all) |
| Is the timer a hard mechanical countdown? | Hard countdown / Soft display only / You decide | No timer (user: "no timer, that's just a rough estimate how long a loop should last by design") |
| LOOP-01 confirmation | Keep visible timer / Remove LOOP-01 | Remove LOOP-01 |
| What triggers loop in Phase 7? | Manual only / Wave clear / (User clarification) | User: "I don't understand — we just go through the rooms and at the end comes a boss and then new loop harder" |
| Loop number display | CarHUD panel / PlayerHUD / Internal only | Yes — show on CarHUD panel |

**User's key clarification (free text):** A loop = Room 1 → Room 2 → Room 3 → Boss defeated → next loop (harder). The "15 minutes" is a design guideline for how long this should take, not a timer. Phase 7 builds the loop infrastructure; Phase 8 wires the actual transition.

**Notes:** LOOP-01 (visible 15-min countdown) removed. Loop transitions stubbed for Phase 8. Phase 7 delivers: loop_number display, difficulty scaling, revive counter, hook point `start_next_loop()`.

---

## Difficulty Scaling Numbers

| Question | Options | Selected |
|----------|---------|----------|
| HP and damage scaling per loop | +25% per loop / +50% per loop / You decide | +25% HP and damage per loop |
| Spawn density scaling | +2 per spawn point / +50% initial count | +50% initial spawn count per loop |
| XP scaling | Yes — XP scales too / No — fixed XP | Yes — XP per orb scales +25% per loop |

**Notes:** All three scaling systems are tied to `GameState.loop_number`. Formula-based, no stored multiplier vars.

---

## HUD Trigger Thresholds

| Question | Options | Selected |
|----------|---------|----------|
| SUSPENSION threshold | ≥15 damage / ≥25% max HP / Every hit | ≥15 damage per hit |
| LIDAR trigger | Every spawn / Initial wave only / Batch 3+ | Elite enemy only (user free text clarification) |
| Elite enemy scope | Build in Phase 7 / Defer to Phase 8 | Build in Phase 7 |
| V2X interval | 30–60s random / Fixed 45s / (user asked what V2X is) | Removed ("raus") |
| HLTH-07 revive limit | Wire in GameState.revives_used + attempt_revive / Defer to Phase 8 | Wire in Phase 7 |

**User's key clarification on LIDAR (free text):** "no, there are normal enemies and then randomly some bigger ones spawn, that's a separate type of enemy that represents LIDAR and then LIDAR lights up" — user wants a new elite enemy type that spawns occasionally; its spawn event triggers the LIDAR indicator. Normal enemy spawns do NOT trigger LIDAR.

**V2X removal:** User said "raus" (German: "out") — V2X auto-trigger indicator removed from Phase 7 scope entirely.

---

## Claude's Discretion

- Elite enemy exact visual (larger ColorRect, distinct dark color)
- Elite enemy exact base HP and damage values
- Elite enemy spawn timer exact randomization within 45–90s range
- Whether elite enemy has higher car-part drop rate
- CarHUD exact panel dimensions
- Loop: N label position within CarHUD panel
- LIDAR indicator fade duration (may want longer than standard 2s given it's a detected threat)
- Cooldown reduction stat boost wiring (noted as `# TODO Phase 7` in Game.gd line 432 — planner evaluates)

## Deferred Ideas

- **V2X auto-trigger** — Removed by user decision. Future phase can add via host timer calling `GameEvents.emit_hud.rpc("v2x")`.
- **Visible 15-minute countdown timer (LOOP-01)** — Removed. 15 minutes is design target only.
- **LIDAR for mob swarms (ROOM-06)** — Phase 8 will add LIDAR triggers for boss-room mob swarm spawns.
