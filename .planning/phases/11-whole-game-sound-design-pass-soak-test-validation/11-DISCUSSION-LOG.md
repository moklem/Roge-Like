# Phase 11: Whole-Game Sound Design Pass & Soak-Test Validation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 11-whole-game-sound-design-pass-soak-test-validation
**Areas discussed:** Camera scope (pre-question), Voice pool & priority scheme, Car-theme sound direction, Music layer scope, Continuous-tick sound treatment

---

## Camera Scope (pre-question)

Phase 10's context noted camera-behavior cleanup was deferred "to Phase 11," but the actual ROADMAP text for Phase 11 only covers sound + soak-test, no camera work. Raised before gray-area selection to resolve the discrepancy.

| Option | Description | Selected |
|--------|-------------|----------|
| Leave deferred | Camera cleanup stays a backlog/future item — Phase 11 stays focused on sound + soak-test as ROADMAP defines it | ✓ |
| Fold into Phase 11 | Add camera-behavior cleanup into this phase's scope — would need a ROADMAP edit first | |
| Handle it separately | User resolves/discusses camera topic outside this workflow | |

**User's choice:** Leave deferred
**Notes:** Camera cleanup remains an unscoped backlog item — see Deferred Ideas in CONTEXT.md.

---

## Voice Pool & Priority Scheme

### Q1: How should must-hear stingers avoid getting drowned out during a dense swarm fight?

| Option | Description | Selected |
|--------|-------------|----------|
| Reserved priority voices | Dedicated AudioStreamPlayers only priority stingers can use | |
| Just bump the pool size | Grow POOL_SIZE from 12 to ~18-20, keep flat round-robin | |
| Both | Bump the pool AND reserve some voices as priority-only | ✓ |

**User's choice:** Both

### Q2: Which cues get a reserved priority voice?

| Option | Description | Selected |
|--------|-------------|----------|
| Just the core 4 | Kill fanfare, evolution transform, downed/revive, boss phase-change | ✓ |
| + Big hit / level-up | Also reserve for the ≥15-dmg big-hit broadcast and level-up burst | ✓ |
| + Boss death | Also reserve for the boss's own death cue | ✓ |

**User's choice:** All three selected — final priority set is 7 cues: kill fanfare, evolution transform, downed, revive, boss phase-change, boss death, big hit/level-up.

### Q3: Concrete pool size / reserved-voice split?

| Option | Description | Selected |
|--------|-------------|----------|
| 20 total / 4 reserved | 16 shared + 4 reserved, priority cues round-robin the reserved set | |
| 18 total / 3 reserved | 15 shared + 3 reserved (ROADMAP's low end) | |
| You decide | Claude picks exact numbers during planning/implementation | ✓ |

**User's choice:** You decide

### Q4: Overflow when two priority cues fire simultaneously and all reserved voices are busy?

| Option | Description | Selected |
|--------|-------------|----------|
| Steal from shared pool | Priority cue grabs a shared/routine voice instead of dropping | ✓ |
| Drop it silently | Newest priority cue doesn't play if reserved voices are all busy | |
| You decide | Claude picks based on implementation simplicity | |

**User's choice:** Steal from shared pool

---

## Car-Theme Sound Direction

### Q1: Should every cue lean into the CARIAD car-part theme, or only some categories?

| Option | Description | Selected |
|--------|-------------|----------|
| Car-themed everywhere | Every cue, including elemental/magic effects, reinterpreted through the car-part lens | |
| Car-themed for weapons/vehicle stuff, generic elsewhere | Weapons/pickups/UI/vehicle-y abilities stay car-themed; elemental FX and organic effects stay natural/generic | ✓ |
| You decide per-cue | Claude uses judgment per sound family | |

**User's choice:** Car-themed for weapons/vehicle stuff, generic elsewhere

### Q2: Should elemental sound cues echo the existing HUD car-framing or go fully generic/elemental?

| Option | Description | Selected |
|--------|-------------|----------|
| Echo the HUD framing | Ice = AC hiss, Fire = engine-overheat hiss/rattle, Earth heal = servo/massage hum | ✓ |
| Fully generic/elemental | Natural fire/ice/earth sounds independent of HUD text | |
| You decide | Claude picks per-element | |

**User's choice:** Echo the HUD framing
**Notes:** This resolves an apparent tension with Q1 — elemental sounds specifically pick up the car metaphor via the HUD's existing framing, even though elemental FX in general stay non-car-themed by default.

### Q3: Should UI/menu sounds match Phase 10's comic identity, or stay subtle/standard?

| Option | Description | Selected |
|--------|-------------|----------|
| Punchy comic-matched | UI sounds get cartoon snap/pop energy | |
| Subtle standard blips | Understated/generic menu clicks | |
| You decide | Claude picks, using Sfx.gd's "deliberately quiet" doc comment as tiebreaker | ✓ |

**User's choice:** You decide

---

## Music Layer Scope

### Q1: Does sound design reach into Music.gd, or stay confined to one-shot SFX?

| Option | Description | Selected |
|--------|-------------|----------|
| SFX only, music untouched | Stay within Sfx.gd/SFX bus entirely | |
| Add a few key music moments | Extend Music.gd for a small number of high-impact moments, layered over the ongoing shuffle | ✓ |
| You decide | Claude judges case-by-case, defaulting SFX-only | |

**User's choice:** Add a few key music moments

### Q2: Which specific moments get a music-layer reaction?

| Option | Description | Selected |
|--------|-------------|----------|
| Boss-phase change (duck + sting) | Music ducks with a sting on boss phase transitions | |
| Evolution transform (swell) | Brief music swell under the evolution closure moment | ✓ |
| Boss death / loop-end (resolve) | Music resolves/swells on boss death and loop transition | ✓ |

**User's choice:** Evolution transform (swell) + Boss death / loop-end (resolve). Boss-phase change explicitly NOT selected — stays SFX-only.

---

## Continuous-Tick Sound Treatment

### Q1: Spinning Tires' continuous orbit-contact damage — onset-only or per-tick?

| Option | Description | Selected |
|--------|-------------|----------|
| Onset-only | One sound on contact start, silent while contact continues | |
| Per-tick (buzzy/continuous) | Each 0.5s damage tick gets its own sound | |
| You decide | Claude defaults toward onset-only/throttled unless it reads worse | ✓ |

**User's choice:** You decide

### Q2: Ice trail zone's continuous slow — onset-only or continuous hum?

| Option | Description | Selected |
|--------|-------------|----------|
| Onset-only | One sound per enemy entering the zone | |
| Continuous hum while inside | Looping ambient hum while any enemy stands in the zone | |
| You decide | Claude defaults toward onset-only for consistency | ✓ |

**User's choice:** You decide

---

## Claude's Discretion

- Exact `POOL_SIZE` number and reserved-voice count within the pool
- UI/menu sound style (punchy comic vs. subtle standard)
- Spinning Tires and Ice trail zone tick-vs-onset treatment (default: onset-only)
- Full audio-parts checklist composition and per-cue sound character within the style rules locked above
- Technical implementation of the reactive music layer (duck/sting/fade mechanics, player architecture)

## Deferred Ideas

- Camera-behavior cleanup (follow-cam remnants, zoom/overview decision) — left deferred, not folded into Phase 11. See Camera Scope section above.
