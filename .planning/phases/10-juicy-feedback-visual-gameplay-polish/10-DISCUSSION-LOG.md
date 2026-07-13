# Phase 10: Juicy Feedback — Visual & Gameplay Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 10-juicy-feedback-visual-gameplay-polish
**Areas discussed:** Combat feedback look, Shake setting surface (DMG-08), Progression moments, Co-op broadcast & spawn telegraph, Hit-stop & shake feel, Ability juice looks, HP bar & hit direction, Element hit VFX

---

## Combat Feedback Look

| Option | Description | Selected |
|--------|-------------|----------|
| Bangers comic style | Bangers font with thick ink outline — extends comic identity into world space | ✓ |
| Plain bold default font | Godot default, bold, white with dark outline | |
| You decide | Claude picks based on swarm readability | |

**User's choice:** Bangers comic style

| Option | Description | Selected |
|--------|-------------|----------|
| Element-colored | Fire orange, Ice light blue, Earth green, plain white | ✓ |
| All white/ink | Uniform white with ink outline | |
| White + crit emphasis only | Color/size pop only for big hits | |

**User's choice:** Element-colored

| Option | Description | Selected |
|--------|-------------|----------|
| Size scales with damage | Continuous font-size ramp + punch-scale pop on big hits | ✓ |
| Two tiers: normal + big | Standard size + bigger treatment above threshold | |
| Uniform size | All numbers identical | |

**User's choice:** Size scales with damage

| Option | Description | Selected |
|--------|-------------|----------|
| Enemy-colored burst, white flash | Death burst in dying enemy's color; white enemy flash, red/white player flash | ✓ |
| Comic 'POW' flavor | Ink-outlined star/shard shapes, comic star accents | |
| You decide | Claude picks, keeping enemy color differentiation | |

**User's choice:** Enemy-colored burst, white flash

---

## Shake Setting Surface (DMG-08)

| Option | Description | Selected |
|--------|-------------|----------|
| Main menu toggle | Cycle-button on MainMenu | ✓ (with addition) |
| In-game hotkey | Key cycles off/low/normal during play | |
| Both menu + hotkey | Menu + hotkey | |
| Config file only | No UI | |

**User's choice:** Main Menu — free-text addition (German): also add Music and SFX volume sliders there. Folded into phase scope.

| Option | Description | Selected |
|--------|-------------|----------|
| Per-client, default normal | Each laptop local, never synced, ships at normal | ✓ |
| Per-client, default low | Ships at low for projected audience | |
| Persist between launches too | Saved to local config file | |

**User's choice:** Per-client, default normal

| Option | Description | Selected |
|--------|-------------|----------|
| Settings sub-panel | Comic-styled Settings button opens panel with shake + sliders | ✓ |
| Inline on main menu | Everything directly on MainMenu | |
| You decide | Claude picks layout | |

**User's choice:** Settings sub-panel

| Option | Description | Selected |
|--------|-------------|----------|
| Shake only | Exactly DMG-08; hit-stop/flashes/particles always play | ✓ |
| All screen effects | Master juice dial scaling everything | |

**User's choice:** Shake only

---

## Progression Moments

| Option | Description | Selected |
|--------|-------------|----------|
| Animation only, no restyle | Pop-in on today's CardOverlay look; user restyles later | |
| Restyle it together now | Claude folds CardOverlay comic restyle into Phase 10 with the pop-in | ✓ |
| Skip until I restyle | Defer PROG-02 | |

**User's choice:** Restyle it together now — supersedes the Comic UI Pass reservation (user had reserved CardOverlay restyle for himself).

| Option | Description | Selected |
|--------|-------------|----------|
| Gold ring + sparks | Expanding golden ring + spark burst | |
| Element-colored burst | Burst takes the player's element color | ✓ |
| Comic star pop | Ink-outlined comic star flash | |

**User's choice:** Element-colored burst

| Option | Description | Selected |
|--------|-------------|----------|
| Flash → burst → reveal | White flash, burst, sprite swap mid-burst | |
| Charge-up then reveal | ~0.5s glow build-up, then burst + sprite swap | ✓ (modified) |
| You decide | Claude designs within locked constraints | |

**User's choice:** Charge-up then reveal, **with element-colored particle burst** (free-text modification).

| Option | Description | Selected |
|--------|-------------|----------|
| Curved swoop + trail | Ghost orb arcs with fading trail | |
| Straight fast dart | Ghost orb shoots directly at bar in ~0.3s, pulse on arrival | ✓ |
| You decide | Claude tunes flight/timing | |

**User's choice:** Straight fast dart

---

## Co-op Broadcast & Spawn Telegraph

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse ≥15 dmg threshold | Same trigger site as Phase 7 SUSPENSION | ✓ |
| Percent of max HP | E.g. ≥20% of victim's max HP | |
| You decide | Claude picks, shared definition with SUSPENSION | |

**User's choice:** Reuse ≥15 dmg threshold

| Option | Description | Selected |
|--------|-------------|----------|
| World FX only | Effects at world position; CarHUD covers off-screen signal | (moot) |
| World FX + edge indicator | Screen-edge arrows toward off-screen teammates | |
| World FX + downed-only marker | Edge marker only for downed teammates | |

**User's choice:** Free text — "We don't have a scrolling cam, we see the whole map at once." Question premise corrected: whole sub-room visible, world FX always on-screen, no edge indicators needed. Follow-up camera question ("keep as-is / discuss now / remove remnants") answered (German): "das in Phase 11 machen diese Themen" — camera topics deferred to Phase 11.

| Option | Description | Selected |
|--------|-------------|----------|
| Tip over + grey, ring + green burst | Sprite tips 90° + desaturates; ring fills; green burst on success | ✓ |
| Comic-flavored | Dizzy stars + comic star pop | |
| You decide | Claude designs within placeholder constraints | |

**User's choice:** Tip over + grey, ring + green burst

| Option | Description | Selected |
|--------|-------------|----------|
| Cosmetic only | Enemy active immediately; ~0.4s materialize effect over it | ✓ |
| Brief real delay | Host delays activation ~0.5s (authoritative change) | |

**User's choice:** Cosmetic only

---

## Hit-stop & Shake Feel (second round)

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle & snappy | Hit-stop ~60–80ms, short sharp shake, fast decay | ✓ |
| Punchy & dramatic | ~100–150ms, stronger shake with rumble tail | |
| Escalating by significance | Barely-there normal kills, full punch on elite/boss | |

**User's choice:** Subtle & snappy

## Ability Juice Looks (second round)

| Option | Description | Selected |
|--------|-------------|----------|
| Ghost afterimages + soft glows | Fading afterimages, soft ring pulse, green sparkle rise, drone pop-in ring | ✓ |
| Streaks + hard shapes | Motion streaks, hard rings, plus-sign particles | |
| You decide | Claude designs consistently with element colors | |

**User's choice:** Ghost afterimages + soft glows

## HP Bar & Hit Direction (second round)

| Option | Description | Selected |
|--------|-------------|----------|
| Ghost chip-away | Instant drop + lingering ghost segment draining after ~0.4s | ✓ |
| Smooth drain | Tween down over ~0.3s with flash | |
| Flash only | Snap + red flash | |

**User's choice:** Ghost chip-away

## Element Hit VFX (second round)

| Option | Description | Selected |
|--------|-------------|----------|
| Burst at impact only | Element-colored burst at hit point, gone in ~0.4s | ✓ |
| Burst + brief ground decal | Plus fading scorch/frost/crack mark ~2s | |
| You decide | Claude picks per SYS-02/03 budget | |

**User's choice:** Burst at impact only

---

## Claude's Discretion

- Exact numeric constants (trauma decay, shake magnitudes per level, hit-stop durations, pool sizes, aggregation window, font-size ramp)
- Damage-number float path/duration and pooling internals
- Settings persistence approach (not required by user)
- Materialize-telegraph composition details, ghost chip-away timings, ring/burst sizes
- Settings sub-panel layout within the comic style
- CardOverlay restyle design specifics

## Deferred Ideas

- Camera behavior topics (follow-cam remnant cleanup, zoom/overview) — user deferred to Phase 11
- In-game hotkey for shake setting
- Ground decals for element hits
- Settings persistence to config file
