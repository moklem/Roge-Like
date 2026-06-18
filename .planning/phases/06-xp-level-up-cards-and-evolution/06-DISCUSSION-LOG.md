# Phase 6: XP, Level-Up Cards & Evolution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 06-xp-level-up-cards-and-evolution
**Areas discussed:** Element upgrade cards, Stage 2 locomotion, XP/level state architecture, HUD layout

---

## Element Upgrade Cards

### What happens when a player picks an element upgrade card?

| Option | Description | Selected |
|--------|-------------|----------|
| Boost proc rate | Fire/Ice proc chance increases 25%→50%→75% per tier | ✓ |
| Upgrade effect tier | Stronger burn/slow/heal per pick, same proc rate | |
| Both — proc rate + strength | Level 2 boosts rate, Level 3 boosts strength | |

**User's choice:** Boost proc rate
**Notes:** Simple and clean. Proc rate doubles per tier.

---

### How many times can a player upgrade their element?

| Option | Description | Selected |
|--------|-------------|----------|
| 2 upgrades max | 25%→50%→75%; card removed from pool after Tier 3 | ✓ |
| 1 upgrade max | 25%→50% only | |
| Unlimited (+15% per pick, cap at 100%) | Stack until 100% | |

**User's choice:** 2 upgrades max (3 tiers total)
**Notes:** element_tier: int tracks current tier (1/2/3).

---

### Earth element upgrade (no proc rate — passive)

| Option | Description | Selected |
|--------|-------------|----------|
| Shockwave upgrade | Faster shockwave cooldown per tier, heal rate unchanged | |
| Heal rate upgrade | Higher heal/sec per tier, shockwave unchanged | |
| Both — heal and shockwave scale | Each tier boosts both heal rate and shockwave cooldown | ✓ |

**User's choice:** Both — heal and shockwave scale
**Notes:** Tier 3 also adds a brief slow (×0.5) on shockwave hit.

---

## Stage 2 Locomotion

### Should Stage 2 have a mechanical movement change?

| Option | Description | Selected |
|--------|-------------|----------|
| Purely visual — same WASD controls | Stage 1→2→3 are cosmetic shape changes; WASD unchanged | ✓ |
| Speed boost at Stage 2 | +20% SPEED when entering Stage 2 | |
| Strafe ability at Stage 2 | Hold Shift to strafe without changing weapon direction | |

**User's choice:** Purely visual — same WASD controls
**Notes:** "Moves like a robot" is flavor text only. No code changes to movement physics.

---

### Stage 3 stat boost?

| Option | Description | Selected |
|--------|-------------|----------|
| Stat boost at Stage 3 | +20% damage and +25 max HP on Stage 3 activation | ✓ |
| Purely visual | Stage 3 is cosmetic only, no extra stats | |

**User's choice:** Stat boost at Stage 3
**Notes:** stage3_damage_mult: float on Player (1.0 → 1.2 on Stage 3). MAX_HP +25, immediate +25 HP.

---

## XP / Level State Architecture

### Where should per-player XP and level live?

| Option | Description | Selected |
|--------|-------------|----------|
| Player.gd (Recommended) | xp, level on Player node; MultiplayerSynchronizer replicates | ✓ |
| GameState.gd | Dict per player in GameState; host sole writer; more RPCs | |

**User's choice:** Player.gd
**Notes:** Aligns with Phase 5 pattern — evolution_stage, health, shield_active all live on Player.

---

## HUD Layout

### Where should the XP bar appear?

| Option | Description | Selected |
|--------|-------------|----------|
| On the player character (world space) | XP bar below HealthBar, moves with player | |
| Screen-edge HUD (CanvasLayer) | Fixed bottom of screen, stays put while player moves | ✓ |

**User's choice:** Screen-edge CanvasLayer
**Notes:** New PlayerHUD.tscn, child of Player scene, visible only on owning peer.

---

### What should the HUD show?

| Option | Description | Selected |
|--------|-------------|----------|
| XP bar + level number + stage indicator | Bottom: LVL N + XP bar + Stage N | ✓ |
| XP bar + level number only | Stage visible via visual shape, no HUD slot | |

**User's choice:** XP bar + level number + stage indicator

---

## Claude's Discretion

- Exact XP orb value for timing (5 XP/orb starting point; planner may tune)
- Exact level for Stage 2 / Stage 3 unlocks (planner calculates from formula + timing targets)
- Invulnerability during card pick = full duration of pick (is_picking_card blocks all damage)
- Color choices for placeholder stage shapes
- Card pool draw implementation (random eligible pool + fallback)
- Level-up indicator on teammates: derived from synced is_picking_card vs separate RPC
- Earth tier implementation in _tick_element match statement
- Stage 3 damage multiplier read path in weapon fire functions

## Deferred Ideas

- Stat boost card exact percentages (start with +10%, tune later)
- XP magnet pull effect — v2 polish
- Card pick visual polish (animated flip, glow, sound) — v2 polish
- Stage 2 locomotion mechanics — explicitly confirmed out of scope
