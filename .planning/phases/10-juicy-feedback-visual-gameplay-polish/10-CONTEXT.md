# Phase 10: Juicy Feedback — Visual & Gameplay Polish - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

The full non-sound juice layer over the already-complete core game: foundational juice infrastructure (Juice autoload, FxLayer, pooled damage numbers, trauma shake), combat feedback (damage numbers, hit-flash, shake, HP-bar animation, hit-stop, death burst, element hit VFX), collection/progression feedback (XP magnetism + travel-to-bar, level-up burst, card overlay pop-in), status-effect sync fix + elemental/ability juice, downed/revive/team-broadcast juice, and the evolution transform closure moment. Covers 27 requirements (SYS-01–03, DMG-01–08, PICK-01–02, PROG-01–03, ABIL-01–06, COOP-01–05). Purely additive presentation layer — zero changes to authoritative game state/logic (one deliberate exception: the ABIL-01 burn/slow sync fix adds replicated flags, and the settings panel adds local-only UI).

**Additions folded in during discussion:**
- Main Menu settings sub-panel: shake off/low/normal + Music volume slider + SFX volume slider (extends the DMG-08 surface; audio plumbing via existing `Music.gd`/`Sfx.gd` buses)
- CardOverlay comic restyle (previously reserved by the user for himself — now explicitly folded into this phase together with the PROG-02 pop-in)

**Not in Phase 10 scope:**
- Sound cues (Phase 11 — SFX-01–03)
- Camera behavior changes (follow-cam remnant cleanup, zoom/overview decisions) — user deferred to Phase 11
- Any authoritative gameplay change (spawn delays, damage changes, new synced state beyond the ABIL-01 fix)

</domain>

<decisions>
## Implementation Decisions

### Combat Feedback Look
- **D-01:** Damage numbers use the **Bangers comic font with thick ink outline** (`assets/ui/fonts/Bangers.ttf`, already wired in `UiStyle.gd`) — extends the Comic UI Pass identity into world space.
- **D-02:** Damage numbers are **element-colored**: Fire = orange, Ice = light blue, Earth = green, non-elemental = white. Pairs with the DMG-07 element hit VFX color language.
- **D-03:** Damage number **size scales continuously with damage magnitude** (small bolt tick = small; big elemental/upgraded hit = noticeably bigger + slight punch-scale pop). No crit system.
- **D-04:** Enemy death burst particles take the **dying enemy's color** (normal/elite/boss read differently). Enemy hit-flash = white tint pop; player hit-flash = red/white (DMG-02).
- **D-05:** Element hit VFX (DMG-07) are **burst-at-impact only** — short element-colored particle burst at the hit point (fire embers, ice shards, earth chunks), gone in ~0.4s. No lingering ground decals.
- **D-06:** Target feel is **subtle & snappy**: hit-stop ~60–80ms on normal kills (slightly longer allowed on elite/boss), shake short and sharp with fast decay. Exact constants planner-tunable against this target.
- **D-07:** HP bar (DMG-04) uses **ghost chip-away**: bar drops instantly to the new value, a white/red ghost segment lingers where the lost HP was and drains after ~0.4s.

### Settings Surface (DMG-08 + user addition)
- **D-08:** Settings live on the **Main Menu** as a comic-styled **Settings sub-panel** (button on MainMenu opens a small panel, styled via `UiStyle.gd` helpers).
- **D-09:** Panel contents: **shake off/low/normal cycle + Music volume slider + SFX volume slider**. Volume sliders drive the existing `Music.gd`/`Sfx.gd` autoloads via audio bus volume.
- **D-10:** All settings are **per-client, never synced**; shake defaults to **normal**.
- **D-11:** The intensity setting governs **screen shake only** — hit-stop, flashes, and particles always play (DMG-08 as written).

### Progression Moments
- **D-12:** **CardOverlay gets its comic restyle in this phase, done by Claude, together with the PROG-02 pop-in animation** (supersedes the earlier Comic UI Pass reservation where the user wanted to restyle it himself). Comic look = UiStyle paper/ink/comic_box language + Bangers.
- **D-13:** Level-up burst (PROG-01) is **element-colored** — takes the player's element color, consistent with D-02.
- **D-14:** Evolution transform (PROG-03) = **charge-up then reveal**: ~0.5s glow/shake build-up on the character, then **element-colored particle burst** + sprite swap to the new stage. Stays within the locked ~1–1.5s, non-blocking, no-camera-lock, no-input-freeze cap. Visible identically to all peers.
- **D-15:** XP orb travel-to-bar (PICK-02) is a **straight fast dart**: ghost orb shoots directly at the XP bar in ~0.3s, bar ticks up with a small pulse on arrival. Minimal visual noise during swarms.

### Co-op Broadcast & Spawn Telegraph
- **D-16:** "Significant/big hit" (COOP-05) **reuses the ≥15 damage single-hit threshold** — same trigger site as Phase 7's SUSPENSION check in `Player.receive_damage()`. One shared definition; the team-visible VFX rides the existing host-side check.
- **D-17:** **Camera reality (user correction):** the whole sub-room is visible at once — the per-player Camera2D is effectively a static per-sub-room overview (sub-rooms fit within one view; see `Player.gd:218` comment), not a scrolling follow-cam. Therefore world-space FX are always on-screen for every player; **no off-screen edge indicators needed**.
- **D-18:** Downed (COOP-01): sprite **tips 90° and desaturates** with a small dust puff. Revive (COOP-02/03): **circular progress ring** fills around the downed player, **green sparkle burst + color snap-back** on success. All world-space, visible to everyone per D-17.
- **D-19:** Enemy spawn telegraph (ABIL-06) is **cosmetic only**: enemy is active immediately as today; a ~0.4s materialize effect (fade-in + ground ring) plays over it. Zero authoritative gameplay change.

### Ability Juice
- **D-20:** Visual direction is **ghost afterimages + soft glows**: dash = fading sprite afterimages (ABIL-02); Tank aura = expanding soft ring pulse in aura color (ABIL-04); heal = green sparkle rise on the healed player (ABIL-03, also satisfies COOP-04 team visibility per D-17); drone deploy = small pop-in burst + brief ring at deploy point (ABIL-05).

### Claude's Discretion
- Exact numeric constants: trauma decay rate, shake magnitudes per intensity level, hit-stop durations within the "subtle & snappy" target, damage-number pool size and aggregation window, font-size ramp curve
- Damage-number float path/duration and pooling implementation details
- Settings persistence (in-memory per launch vs. config file) — user did not require persistence
- Exact materialize-telegraph composition, ghost chip-away timings, ring/ burst sizes
- Layout details of the Settings sub-panel within the comic style
- CardOverlay restyle specifics (user picked "restyle it together now" without constraining the design beyond the established UiStyle comic language)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone Research (primary technical authority)
- `.planning/research/SUMMARY.md` — full research backing: Pattern A/B/C decision table, CPUParticles2D-only rule, no-`Engine.time_scale` rule, FxLayer parenting, pooling/trauma infra, 6-wave sequencing, discovered burn/slow sync bug, open numeric-constant flags
- `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`, `.planning/research/STACK.md`, `.planning/research/FEATURES.md` — detailed per-topic research behind SUMMARY.md

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 10 — 27 requirements, success criteria, suggested internal wave sequencing (1: infra → 2: combat → 3: collection/progression → 4: status-fix + elemental/ability → 5: downed/revive/broadcast → 6: evolution), full pitfall watch
- `.planning/REQUIREMENTS.md` §v1.1 — SYS-01–03, DMG-01–08, PICK-01–02, PROG-01–03, ABIL-01–06, COOP-01–05 full text

### Prior Phase Architecture
- `.planning/phases/07-carhud-loop-timer-difficulty-scaling/07-CONTEXT.md` — D-09: the ≥15 dmg SUSPENSION threshold reused for COOP-05 (D-16 above); `GameEvents.emit_hud` RPC broadcast pattern to extend
- `.planning/phases/06-xp-level-up-cards-and-evolution/06-CONTEXT.md` — CanvasLayer-only UI discipline (W4), CardOverlay/PlayerHUD architecture, host-authoritative card flow
- `.planning/phases/09-map-overhaul-tilemap-sub-rooms/09-CONTEXT.md` — D-01–D-03: per-player Camera2D setup that shake will drive; sub-room/FxLayer parenting context

### Live Code (read before modifying)
- `scenes/Player.gd` — `_last_health_seen` diff-watch idiom (line ~236, the pattern to extend), `receive_damage()` SUSPENSION site, `update_camera_limits()` + overview-cam comment (line ~218)
- `scenes/enemies/Enemy.gd` — `_last_hp_seen` diff-watch idiom (line ~35/111), status tint code (burn/slow host-only bug to fix, ABIL-01)
- `autoloads/GameEvents.gd` — `player_downed`/`player_revived` signals scaffolded but unwired (COOP-01–03 wiring point); `emit_hud` reliable-broadcast pattern to extend for big-hit
- `autoloads/Sfx.gd` / `autoloads/Music.gd` — 12-voice pool + safe-load pattern; volume sliders (D-09) drive these via audio buses
- `scenes/ui/UiStyle.gd` — comic helpers (PAPER/INK, comic_box, Bangers BUTTON_FONT_PATH) — the style source for damage numbers, settings panel, and CardOverlay restyle
- `scenes/ui/CardOverlay.gd` + `scenes/ui/CardOverlay.tscn` — pop-in + comic restyle target (D-12); shared by level-up and sub-room weapon choice (PROG-02)
- `scenes/ui/MainMenu.gd` + `scenes/ui/MainMenu.tscn` — settings sub-panel integration point (D-08)
- `scenes/ui/PlayerHUD.gd` — XP bar (travel-to-bar arrival pulse, ghost chip-away HP treatment applies to health bars)
- `scenes/Game.gd` — FxLayer container will live under Game; `_show_dash_shockwave`-style tween precedent

### Assets
- `assets/ui/fonts/Bangers.ttf` — damage-number and comic-UI font (SIL OFL)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`_last_hp_seen` / `_last_health_seen` diff-watch idiom** (Enemy.gd, Player.gd) — confirmed live; the Pattern-A backbone for damage numbers, hit-flash, HP-bar animation, downed collapse, evolution trigger
- **`GameEvents.player_downed` / `player_revived` signals** — declared but unwired; COOP-01–03 connects them
- **`GameEvents.emit_hud` RPC** — the reliable-broadcast pattern to extend (not fork) for the big-hit positional event
- **`UiStyle.gd` comic helpers + Bangers font** — style source for all new UI (damage numbers, settings panel, CardOverlay restyle)
- **`Sfx.gd` 12-voice pool / `Music.gd`** — volume-slider targets; pool extension itself is Phase 11
- **Dash-shockwave tween precedent in `Game.gd`** — parent-to-Game + tween-fade model for transient VFX

### Established Patterns
- CPUParticles2D only (GPUParticles2D silently fails under gl_compatibility) — SYS-01
- Never `Engine.time_scale` / `SceneTree.paused` — hit-stop is a local per-peer cosmetic scale read only by presentation code
- Transient VFX parented to persistent FxLayer, `global_position` captured before `queue_free()`; death burst via RPC before despawn
- CanvasLayer for all local UI; card overlay never pauses the tree
- Host-authoritative everything; presentation reacts to replicated state (Pattern A) or reliable RPC (Pattern B)

### Integration Points
- `Player.receive_damage()` — big-hit check site (≥15 dmg, same as SUSPENSION); hit-flash/shake/HP-ghost triggers
- Enemy `MultiplayerSynchronizer` replicated set — add `is_burning`/`is_slowed` (verify exact sync-config mechanism during planning, per roadmap pitfall watch)
- `Game.tscn` — new persistent `FxLayer` node; new `Juice.gd` (or JuiceManager) autoload in `project.godot`
- `MainMenu.tscn` — Settings sub-panel button + panel
- `CardOverlay.tscn` — pop-in animation + comic restyle

</code_context>

<specifics>
## Specific Ideas

- **Camera correction from the user:** "We don't have a scrolling cam, we see the whole map at once" — the per-player Camera2D exists but sub-rooms fit in one view (overview feel). Planner must not design for off-screen teammates; shake still drives the local Camera2D.
- **One color language everywhere:** element colors (fire orange / ice blue / earth green) recur across damage numbers, level-up burst, evolution burst, and element hit VFX — build the color map once and share it.
- **Comic identity extends into world space:** Bangers + ink outline for damage numbers; CardOverlay and Settings panel join the paper/ink comic look.
- **"Subtle & snappy" is the overall feel target** — readable swarm combat over drama; the projected demo audience is a consideration (shake default normal, but per-laptop adjustable).

</specifics>

<deferred>
## Deferred Ideas

- **Camera behavior topics** (follow-cam remnant cleanup, zoom/overview decision, position smoothing) — user explicitly deferred to Phase 11
- **In-game hotkey for the shake setting** — Main Menu sub-panel chosen; a hotkey could be added later if live-demo adjustment proves necessary
- **Ground decals for element hits** (scorch/frost/crack marks lingering ~2s) — burst-only chosen for swarm readability; decals are a possible later polish
- **Settings persistence to config file** — not required; revisit if per-launch reset annoys during demo prep

</deferred>

---

*Phase: 10-juicy-feedback-visual-gameplay-polish*
*Context gathered: 2026-07-13*
