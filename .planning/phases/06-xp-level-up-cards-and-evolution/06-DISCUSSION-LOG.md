# Phase 6: XP, Level-Up Cards & Evolution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 6-xp-level-up-cards-and-evolution
**Areas discussed:** XP thresholds & pacing, Card overlay UX, Weapon upgrade stats, Phase 5 dependency scope

---

## XP thresholds & pacing

### XP per orb

| Option | Description | Selected |
|--------|-------------|----------|
| 10 XP per orb | ~10 kills per level-up — fast, demo-friendly | |
| 5 XP per orb | ~20 kills per level-up — slower pace | ✓ |
| You decide | Claude picks default | |

**User's choice:** 5 XP per orb
**Notes:** Slower pace preferred — more deliberate progression.

### XP scaling per level

| Option | Description | Selected |
|--------|-------------|----------|
| Flat — 100 XP per level | Every level takes the same 20 kills | |
| Increasing — +50 XP each level | Early levels fast, later levels slower | ✓ |
| You decide | Claude picks formula | |

**User's choice:** Increasing thresholds: level N requires (100 + (N-1) × 50) XP above previous level.

### Stage 2 timing

| Option | Description | Selected |
|--------|-------------|----------|
| Stage 2 at Level 5, Stage 3 at Level 10 | Mid-run Stage 2, late Stage 3 | |
| Stage 2 at Level 3, Stage 3 at Level 6 | Earlier evolution | |
| Stage 2 at Level 7, Stage 3 at Level 12 | Later, risk audience not seeing Stage 3 | |
| You decide | Claude picks thresholds | |

**User's choice:** Stage 2 should be reachable before Room 3 in Run 1. Planner calculates exact level to ensure this timing.
**Notes:** Not a specific level number — a timing constraint. Planner must verify with XP formula and current spawn rates.

### Stage 3 timing

| Option | Description | Selected |
|--------|-------------|----------|
| During Room 3 / boss fight | Climactic moment, always visible in demo | |
| Late same run — if run goes well | Bonus for skilled play, not guaranteed | |
| You decide | Claude picks | |

**User's choice:** Room 2 of the second run.
**Notes:** Stage 3 is not meant to be hit in Run 1. XP and evolution carry over via LOOP-06, so players who survive into loop 2 hit Stage 3 in Room 2 of that loop.

---

## Card overlay UX

### Player state during card pick

| Option | Description | Selected |
|--------|-------------|----------|
| Freeze + still vulnerable | Tension — can be hit while reading cards | |
| Freeze + briefly invulnerable | Safe window to pick without risk | ✓ |
| Can still move | Overlay is translucent, player still active | |

**User's choice:** Freeze + invulnerable while picking.

### Time limit

| Option | Description | Selected |
|--------|-------------|----------|
| No time limit | Wait until player picks | ✓ |
| Auto-pick after ~10 seconds | Keeps game moving if player is AFK | |

**User's choice:** No time limit — wait indefinitely.
**Notes:** Good for demo context where players may be distracted by the audience.

### Card navigation

| Option | Description | Selected |
|--------|-------------|----------|
| Press 1/2/3 to pick | Immediate number-key selection | |
| Arrow keys + Enter | Gamepad-style navigation | |
| Click (mouse) | Mouse selection | |

**User's choice:** A/D keys to cycle between the 3 cards, Space or Enter to confirm.
**Notes:** Keyboard-only per PROJECT.md. A/D feels more natural than number keys for cycling.

### Teammate indicator

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — "[Name] is leveling up!" label | Visible to all peers above frozen player | ✓ |
| No indicator | Invisible to others | |
| You decide | Claude decides | |

**User's choice:** Yes — label visible on all peers.

---

## Weapon upgrade stats

### Upgrade approach

| Option | Description | Selected |
|--------|-------------|----------|
| Generic: +25% damage, -15% cooldown per level | One formula for all weapons | |
| Per-weapon — each has unique Level 2/3 behavior | More interesting, needs design spec | ✓ |
| You decide | Claude picks | |

**User's choice:** Per-weapon upgrade behaviors.

### Behavior definition

| Option | Description | Selected |
|--------|-------------|----------|
| Claude proposes all 6 weapons in CONTEXT.md | Fast, user reviews before planning | ✓ |
| Walk through weapon by weapon | User-driven, ~18 more questions | |

**User's choice:** Claude proposes in CONTEXT.md.
**Notes:** All 6 weapon upgrade behaviors (Level 2 + Level 3) are specified in CONTEXT.md D-11. User can revise before running /gsd-plan-phase 6.

---

## Phase 5 dependency scope

### Phase ordering decision

| Option | Description | Selected |
|--------|-------------|----------|
| Stub Phase 5 dependencies — skip element cards and signature abilities | Phase 6 proceeds without Phase 5 | |
| Do Phase 5 first, then return to Phase 6 | Full card pool available at planning time | ✓ |
| Include element upgrade cards as stubs (no real effect) | Visual completeness without Phase 5 | |

**User's choice:** Do Phase 5 first, then return to Phase 6.
**Notes:** This CONTEXT.md is written and ready. Run /gsd-discuss-phase 5 next, then /gsd-plan-phase 5, then /gsd-plan-phase 6.

### Stage 2 signature ability delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-granted at Stage 2 threshold | Automatic, no card pick needed | ✓ |
| Via special card in level-up pool | Requires explicit card selection | |

**User's choice:** Auto-granted when Stage 2 XP threshold is hit.

### Evolution visual approach

| Option | Description | Selected |
|--------|-------------|----------|
| Claude designs placeholder shapes | Stage 1 compact rectangle → Stage 2 T/cross shape → Stage 3 armored rectangle | ✓ |
| User describes stage shapes | Custom descriptions | |

**User's choice:** Claude designs. Specifications in CONTEXT.md D-12.

---

## Claude's Discretion

- Exact level for Stage 2 and Stage 3 XP thresholds (planner calculates from formula and timing targets)
- Invulnerability duration during card pick (suggest 0.5–1s or full pick duration)
- Color choices for evolution stage placeholder shapes
- Card pool draw implementation (eligible pool filtering, fallback card logic)
- Whether level-up indicator uses RPC broadcast or derived from synced `is_picking_card` property

## Deferred Ideas

- Stat boost card exact +% values (tuning — start at +10%, adjust in playtesting)
- Element upgrade card effects (depend on Phase 5)
- XP magnet range / orb drift-to-player effect (v2 QOL)
- Card overlay visual polish (animation, glow, sound — v2 scope)
