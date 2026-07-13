# Phase 10: Juicy Feedback — Visual & Gameplay Polish - Research

**Researched:** 2026-07-13
**Domain:** Game-feel/"juice" presentation layer for an existing Godot 4.6 host-authoritative LAN co-op roguelike (gl_compatibility renderer)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Combat Feedback Look**
- **D-01:** Damage numbers use the **Bangers comic font with thick ink outline** (`assets/ui/fonts/Bangers.ttf`, already wired in `UiStyle.gd`) — extends the Comic UI Pass identity into world space.
- **D-02:** Damage numbers are **element-colored**: Fire = orange, Ice = light blue, Earth = green, non-elemental = white.
- **D-03:** Damage number **size scales continuously with damage magnitude** (small bolt tick = small; big elemental/upgraded hit = noticeably bigger + slight punch-scale pop). No crit system.
- **D-04:** Enemy death burst particles take the **dying enemy's color** (normal/elite/boss read differently). Enemy hit-flash = white tint pop; player hit-flash = red/white (DMG-02).
- **D-05:** Element hit VFX (DMG-07) are **burst-at-impact only** — short element-colored particle burst at the hit point, gone in ~0.4s. No lingering ground decals.
- **D-06:** Target feel is **subtle & snappy**: hit-stop ~60–80ms on normal kills (slightly longer allowed on elite/boss), shake short and sharp with fast decay. Exact constants planner-tunable against this target.
- **D-07:** HP bar (DMG-04) uses **ghost chip-away**: bar drops instantly to the new value, a white/red ghost segment lingers where the lost HP was and drains after ~0.4s.

**Settings Surface (DMG-08 + user addition)**
- **D-08:** Settings live on the **Main Menu** as a comic-styled **Settings sub-panel** (button on MainMenu opens a small panel, styled via `UiStyle.gd` helpers).
- **D-09:** Panel contents: **shake off/low/normal cycle + Music volume slider + SFX volume slider**. Volume sliders drive the existing `Music.gd`/`Sfx.gd` autoloads via audio bus volume.
- **D-10:** All settings are **per-client, never synced**; shake defaults to **normal**.
- **D-11:** The intensity setting governs **screen shake only** — hit-stop, flashes, and particles always play (DMG-08 as written).

**Progression Moments**
- **D-12:** **CardOverlay gets its comic restyle in this phase, done by Claude, together with the PROG-02 pop-in animation** (supersedes the earlier Comic UI Pass reservation). Comic look = UiStyle paper/ink/comic_box language + Bangers.
- **D-13:** Level-up burst (PROG-01) is **element-colored** — takes the player's element color, consistent with D-02.
- **D-14:** Evolution transform (PROG-03) = **charge-up then reveal**: ~0.5s glow/shake build-up, then **element-colored particle burst** + sprite swap. Stays within the locked ~1–1.5s, non-blocking, no-camera-lock, no-input-freeze cap. Visible identically to all peers.
- **D-15:** XP orb travel-to-bar (PICK-02) is a **straight fast dart**: ghost orb shoots directly at the XP bar in ~0.3s, bar ticks up with a small pulse on arrival. Minimal visual noise during swarms.

**Co-op Broadcast & Spawn Telegraph**
- **D-16:** "Significant/big hit" (COOP-05) **reuses the ≥15 damage single-hit threshold** — same trigger site as Phase 7's SUSPENSION check in `Player.receive_damage()`. One shared definition; the team-visible VFX rides the existing host-side check.
- **D-17:** **Camera reality (user correction):** the whole sub-room is visible at once — the per-player Camera2D is effectively a static per-sub-room overview (sub-rooms fit within one view; see `Player.gd:218` comment), **not** a scrolling follow-cam. Therefore world-space FX are always on-screen for every player; **no off-screen edge indicators needed.**
- **D-18:** Downed (COOP-01): sprite **tips 90° and desaturates** with a small dust puff. Revive (COOP-02/03): **circular progress ring** fills around the downed player, **green sparkle burst + color snap-back** on success. All world-space, visible to everyone per D-17.
- **D-19:** Enemy spawn telegraph (ABIL-06) is **cosmetic only**: enemy is active immediately as today; a ~0.4s materialize effect (fade-in + ground ring) plays over it. Zero authoritative gameplay change.

**Ability Juice**
- **D-20:** Visual direction is **ghost afterimages + soft glows**: dash = fading sprite afterimages (ABIL-02); Tank aura = expanding soft ring pulse in aura color (ABIL-04); heal = green sparkle rise on the healed player (ABIL-03, also satisfies COOP-04 per D-17); drone deploy = small pop-in burst + brief ring at deploy point (ABIL-05).

### Claude's Discretion
- Exact numeric constants: trauma decay rate, shake magnitudes per intensity level, hit-stop durations within the "subtle & snappy" target, damage-number pool size and aggregation window, font-size ramp curve.
- Damage-number float path/duration and pooling implementation details.
- Settings persistence (in-memory per launch vs. config file) — user did not require persistence.
- Exact materialize-telegraph composition, ghost chip-away timings, ring/burst sizes.
- Layout details of the Settings sub-panel within the comic style.
- CardOverlay restyle specifics (user picked "restyle it together now" without constraining the design beyond the established UiStyle comic language).

### Deferred Ideas (OUT OF SCOPE)
- **Camera behavior topics** (follow-cam remnant cleanup, zoom/overview decision, position smoothing) — user explicitly deferred to Phase 11.
- **In-game hotkey for the shake setting** — Main Menu sub-panel chosen; a hotkey could be added later if live-demo adjustment proves necessary.
- **Ground decals for element hits** (scorch/frost/crack marks lingering ~2s) — burst-only chosen for swarm readability; decals are a possible later polish.
- **Settings persistence to config file** — not required; revisit if per-launch reset annoys during demo prep.
- **Sound cues** (Phase 11 — SFX-01–03).
- **Any authoritative gameplay change** (spawn delays, damage changes, new synced state beyond the ABIL-01 fix).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SYS-01 | All new particle effects use CPUParticles2D | Confirmed live convention (`Player._spawn_heal_particles`/`_spawn_driver_particles` already use `CPUParticles2D`; zero `GPUParticles2D` usages found in codebase). Pitfall 2 below explains the renderer restriction. |
| SYS-02 | Damage numbers and screen shake pooled/capped | Pattern A + shared `JuiceManager` pooling infra (Foundational wave). Pitfall 5 below. |
| SYS-03 | Juice nodes cleaned up without leaking over 15 min | Shared spawn+cleanup helper + defensive backstop timers (Foundational wave). Pitfall 6 below. |
| DMG-01 | Floating damage number on hit | Pattern A — extend `Enemy._process` `_last_hp_seen` diff-watch (already reacts via `Sfx.hit()`). D-01/D-02/D-03 styling. |
| DMG-02 | Player hit-flash red/white | Pattern A — extend `Player._process` `_last_health_seen` diff-watch (health decreasing branch, currently only handles increase for heal particles). |
| DMG-03 | Capped screen shake on player damage | Trauma-accumulator `JuiceManager.add_trauma()`, local per-peer `Camera2D` (already gated `enabled = is_multiplayer_authority()`). |
| DMG-04 | HP bar flash + ghost chip-away animate-down | Presentation-only change to `Player._process` HealthBar update + Enemy equivalent; D-07 ghost segment. |
| DMG-05 | Hit-stop on kill, local cosmetic only | Pattern C — `JuiceManager.hitstop()`/`cosmetic_delta()`, triggered from `Enemy._exit_tree()` (fires on every peer when spawner-replicated `queue_free()` removes the node). Never `Engine.time_scale`/`SceneTree.paused` (Pitfall 1). |
| DMG-06 | Enemy death particle burst | Pattern B — RPC-before-`queue_free()` carrying `global_position`, parented to persistent FxLayer, colored by enemy type per D-04 (Pitfall 3/4). |
| DMG-07 | Element-specific hit VFX (fire/ice/earth) | Requires ABIL-01 sync fix first (Status-Effect Visibility Gap below); burst-only per D-05. |
| DMG-08 | Global shake intensity setting (off/low/normal) | New Settings sub-panel on MainMenu (D-08/D-09/D-10/D-11); governs shake only. |
| PICK-01 | XP orb magnetism | Local cosmetic tween in `XpOrb._process` (new) toward nearest already-replicated player position; real collection RPC (`_request_collect`) untouched. |
| PICK-02 | XP orb travel-to-bar, bar updates on arrival | Decouple `PlayerHUD.update_hud()` display value from instant `GameState._sync_team_xp`; D-15 straight-dart ghost clone. |
| PROG-01 | Level-up burst | Pattern A — `is_picking_card` diff already exists (`Player._process`); element-colored per D-13. |
| PROG-02 | Card overlay pop-in animation (shared component) | `CardOverlay.gd`/`CardOverlay.tscn` — currently has ZERO `UiStyle` calls and no entrance animation; this phase adds both the comic restyle (D-12) and the pop-in. |
| PROG-03 | Evolution transform closure moment | Hooks `Player.set_evolution_stage()` (already an RPC firing on all peers); D-14 charge-up-then-reveal sequence; screen-space effects (shake/flash) gated `is_multiplayer_authority()`, particle/sprite-swap visible to all. |
| ABIL-01 | Burn/slow status visible on all clients | **Confirmed live bug**: Enemy's `SceneReplicationConfig` (Enemy.tscn) only replicates `position`, `current_hp`, `state` — NOT `modulate` or any status flag. `apply_burn()`/`apply_slow()`/`_tick_status_effects()` run only where `_physics_process` executes, which is host-only (`set_physics_process(is_multiplayer_authority())`). Fix: add `is_burning`/`is_slowed` booleans to the replicated set. |
| ABIL-02 | Speedster dash trail/afterimage | Diff `dash_invincible` (already replicated); D-20 ghost afterimage direction. |
| ABIL-03 | Engineer heal sparkle | Already implemented in principle — `_spawn_heal_particles()` reacts to the health-diff (D-20 confirms direction: green sparkle rise). Also satisfies COOP-04. |
| ABIL-04 | Tank aura pulse | Diff `shield_active` (already replicated); D-20 expanding ring pulse. |
| ABIL-05 | Engineer drone deploy effect | `HealDrone._ready()` already runs identically on every peer (spawner-replicated) — hook the pop-in/ring there. |
| ABIL-06 | Enemy spawn-in telegraph | `Enemy._ready()`/`EliteEnemy._ready()`/`Boss._ready()` already run on every peer; D-19 cosmetic-only fade-in + ring. |
| COOP-01 | Downed collapse animation | Diff `is_downed` (already replicated, already drives a grayscale tint); D-18 tip+desaturate+dust puff. |
| COOP-02 | Team-visible revive progress ring | **Confirmed live gap**: `Game._update_revive_bar()` calls `p.set_revive_progress.rpc_id(target_id, progress)` — sent ONLY to the downed player's own client (`@rpc("any_peer","call_remote",...)`). Must widen to a broadcast so every peer renders the ring (safe — Player nodes are named deterministically `Player_%d`, confirmed in `Game._do_spawn`). |
| COOP-03 | Team-visible revive success burst | `is_downed` true→false diff (already replicated) — Pattern A, zero new RPC. |
| COOP-04 | Team-visible healing feedback | Already satisfied structurally by the existing `_last_health_seen` diff pattern (comment: "health is synced, so every peer sees the burst") — this phase makes it juicier, doesn't re-architect it. |
| COOP-05 | Team-visible big-hit feedback | New `GameEvents.emit_big_hit(pos)` RPC (D-16, reuses the existing ≥15-dmg `from_elite` SUSPENSION trigger site in `Player.receive_damage()` / `Game.notify_significant_hit()`). |
</phase_requirements>

## Summary

This phase adds a purely additive presentation layer — screen shake, hit-stop, floating damage numbers, particle bursts, pickup/XP-orb magnetism, evolution VFX, ability juice, downed/revive juice, and a Settings sub-panel — to a Godot 4.6 host-authoritative LAN co-op roguelike whose core loop is already complete. A dedicated milestone-level research pass was already completed today (`.planning/research/{SUMMARY,ARCHITECTURE,PITFALLS,STACK,FEATURES}.md`) and is the primary technical authority for this phase; this document synthesizes that research specifically for Phase 10's 27 requirements, cross-checked against direct reads of the current `Enemy.tscn`, `Player.gd`, `Game.gd`, `Sfx.gd`/`Music.gd`, `CardOverlay.gd`, `MainMenu.tscn`, `GameState.gd`, and `HealDrone.gd` performed in this session.

**The single most important architectural fact:** this codebase already has a proven, zero-new-RPC pattern for "juice visible to every player" — `Enemy._process` and `Player._process` diff already-replicated fields (`current_hp`, `health`, `is_downed`, `evolution_stage`, `shield_active`, `dash_invincible`, `is_picking_card`) frame-to-frame and react locally on every peer independently. Most of this phase's requirements extend this exact idiom. New RPCs are needed only for (a) despawn-adjacent effects that can't be diffed reliably (death burst — must fire before `queue_free()`), (b) a genuinely new payload the existing broadcast can't carry (`big_hit(pos)`), and (c) widening one existing single-target RPC to a broadcast (`set_revive_progress`).

**Two hard constraints govern every effect in this phase, decided once and never re-litigated per-effect:** (1) hit-stop must never touch `Engine.time_scale` or `SceneTree.paused` — both would desync this project's un-synchronized client-simulated bullets (`Bullet.gd` has no `MultiplayerSynchronizer`) or freeze the host's authoritative simulation for every peer; implement it as a local, per-peer cosmetic scale read only by presentation code. (2) every new particle effect must be `CPUParticles2D` — `GPUParticles2D` silently fails to render under this project's `gl_compatibility` renderer, confirmed by `project.godot`'s `renderer/rendering_method="gl_compatibility"` and by the fact that zero `GPUParticles2D` usages exist anywhere in the current codebase.

**Two genuinely new findings from this session's direct codebase verification** (not present in the milestone-level research files, both must inform planning): (A) **the audio-bus assumption in CONTEXT.md D-09 does not yet hold** — `Sfx.gd` and `Music.gd` both hard-code `p.bus = "Master"`; there is no separate "Music" or "SFX" audio bus defined anywhere (no `default_bus_layout.tres` exists), so the Settings-panel volume sliders cannot simply "drive existing buses" — new buses must be created first. (B) `CardOverlay.gd`/`CardOverlay.tscn` currently has **zero `UiStyle` calls and no entrance animation** — the comic restyle (D-12) and pop-in (PROG-02) are both fully greenfield within this file, not incremental tweaks.

**Primary recommendation:** Follow the roadmap's 6-wave internal sequencing (infra → combat → collection/progression → status-fix+elemental/ability → downed/revive/broadcast → evolution), building a single `JuiceManager`/`Juice.gd` autoload plus a persistent `FxLayer` node in `Game.tscn` in Wave 1 before any consuming effect exists, and add the two new audio buses + a `Settings.gd` client-only autoload (or a static/singleton pattern living on MainMenu) in the same foundational wave since DMG-08's settings surface has zero dependencies on any other wave.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Damage numbers, hit-flash, HP-bar ghost-chip | Client (per-peer local reactive) | — | Pure presentation diff-watch on already-replicated `current_hp`/`health`; no server involvement beyond existing damage RPCs |
| Screen shake + hit-stop | Client (per-peer local, own `Camera2D` only) | — | Camera2D is per-peer/local by existing design (`enabled = is_multiplayer_authority()`); must never touch engine-global state |
| Death particle burst | Client (local render) | Host (RPC origin) | Host fires the RPC with position before `queue_free()`; every peer independently renders its own burst |
| Element hit VFX (fire/ice/earth) | Client (local reactive) | Host (owns the sync-fix data) | Depends on `is_burning`/`is_slowed` becoming host-authoritative *and* replicated — host still owns gameplay math, client reacts visually |
| XP orb magnetism / travel-to-bar | Client (cosmetic-only tween) | — | Deliberately NOT synced — ghost-clone flight only; real collection RPC stays untouched, avoiding new netcode surface |
| Card overlay pop-in + comic restyle | Client (local `CanvasLayer` UI) | — | Never `SceneTree.paused`; purely local per-peer UI, matches existing W4 discipline |
| Evolution transform | Client (local render, gated screen-fx) | Host (RPC origin, already exists) | `set_evolution_stage` RPC already broadcasts; screen-space personal effects (shake/flash) gated to owner, particle/sprite-swap visible to all |
| Settings sub-panel (shake/volume) | Client (local-only, never synced) | — | Per-client by explicit decision (D-10); reads/writes local autoload state and `AudioServer` bus volumes only |
| Downed/revive juice (broadcast) | Client (local render) | Host (RPC broadcast origin) | `Game.gd` already accumulates revive progress host-side; must widen the existing single-target RPC to reach every peer |
| Big-hit team broadcast | Host (RPC origin, reuses SUSPENSION site) | Client (local render on every peer) | New `GameEvents.emit_big_hit(pos)` extends the existing `emit_hud` reliable-broadcast pattern |
| Status-effect sync fix (ABIL-01) | Host (authoritative tick, unchanged) | Client (new replicated read) | Gameplay math (DoT tick, speed multiplier) stays host-only; only the *visibility* of the resulting flag becomes client-readable |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Tween` (`create_tween()`) | Godot 4.6 core | Procedural juice animation: scale-pop, fade, position float, ring expand, ghost chip-away | Already this codebase's established juice tool (`_show_dash_shockwave`, `_show_earth_shockwave` both build a `Tween` inline). Supports `set_ignore_time_scale()` so UI juice runs smoothly through any local hit-stop dip. `[VERIFIED: direct codebase read — scenes/Player.gd, scenes/Game.gd]` |
| `CPUParticles2D` | Godot 4.6 core | Every new particle burst: hit sparks, death burst, level-up, evolution stinger, pickup pop, ability juice, element hit VFX | The ONLY particle node proven to render under this project's `gl_compatibility` renderer (`GPUParticles2D` requires compute shaders, unsupported on Compatibility). Zero `GPUParticles2D` usages found anywhere in the current codebase — `_spawn_heal_particles`/`_spawn_driver_particles` in `Player.gd` already establish the convention. `[VERIFIED: direct codebase read + project.godot renderer config]` |
| Hand-rolled trauma-based `Camera2D` shake | Godot 4.6 core (no built-in shake API) | Screen shake on damage/kills, magnitude-capped | Each `Player.tscn` already owns its own `Camera2D`, `enabled` only for the local authority peer — shake is naturally local/per-client with zero networking changes needed. `[CITED: kidscancode.org Godot 4 Screen Shake recipe; Shaggy Dev "Better screen shake"]` |
| Local opt-in "hitstop scale" float (never `Engine.time_scale`) | Godot 4.6 core | Hit-stop / freeze-frame on kills and big hits | `Engine.time_scale` is process-global — on host it throttles the authoritative `Enemy._physics_process`/`NavigationAgent2D` for every connected peer; on a client it desyncs local rendering from the un-synced `Bullet.gd` simulation (confirmed no `MultiplayerSynchronizer` on Bullet). `[VERIFIED: direct codebase read — scenes/projectiles/Bullet.gd, scenes/enemies/Enemy.gd]` |
| `AnimationPlayer` or `Tween`-chain | Godot 4.6 core | Evolution transform "closure moment" sequence (D-14 charge-up → reveal) | Recommended for a fixed, reusable, non-parametric sequence; `Tween`-chain is an acceptable simpler alternative if the sequence stays short (roadmap flags this as a Claude's-discretion implementation choice, not a requirement). |
| `Label`/`RichTextLabel` (world-space) | Godot 4.6 core | Floating damage numbers | Spawn as sibling under `Game` (mirrors existing `game.add_child(ring)` pattern in `_show_dash_shockwave`); `RichTextLabel` BBCode gives element-color + size-scale (D-02/D-03) for free. |
| `AudioServer` bus volume (`set_bus_volume_db`) | Godot 4.6 core | Settings-panel Music/SFX volume sliders (D-09) | **New buses required** — see Pitfall 7 below; this is the standard mechanism once buses exist. |
| `AudioStreamPlayer` pool extension (`Sfx.gd`) | Existing autoload | (Sound cues are Phase 11 scope, but the settings volume plumbing touches this file this phase) | No new pool logic needed this phase — only a `bus` reassignment from `"Master"` to a new `"SFX"` bus. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| New `autoloads/Juice.gd` (or `JuiceManager.gd`) | New file | Facade for every juice moment: shake, cosmetic hitstop, damage numbers, flash, particle bursts | Central integration point — prevents ~10 new effect types from each hand-rolling `CPUParticles2D.new()` inline (the existing `Player.gd` already shows early duplication risk between `_spawn_heal_particles`/`_spawn_driver_particles`). |
| New `scenes/vfx/` folder | New folder | `DamageNumber.tscn/.gd`, `HitFlash.gd`, `ImpactBurst.gd` parametrized builders | Replaces ad hoc inline particle construction with one reusable, parametrized builder (color, count, gravity, lifetime). |
| New `Settings.gd` client-only autoload (or static state on MainMenu) | New file | Holds shake intensity enum + volume floats, applies them to `AudioServer` bus indices and exposes `shake_multiplier()` to `Juice.gd` | Per-client, never synced (D-10); in-memory only per D-Claude's-discretion (no persistence required). |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Ghost-clone cosmetic XP-orb magnetism (real collection RPC untouched) | Fully host-authoritative synced orb magnetism (new `MultiplayerSynchronizer` on `XpOrb.tscn`, host-side `_physics_process`) | More "correct" simulation (true chase, no fixed capture radius) but adds new netcode surface for a purely cosmetic ask — **recommend the ghost-clone approach for this phase** per D-15's "straight fast dart" spec, which doesn't need true synced chasing anyway. |
| `AnimationPlayer` for evolution transform | Pure `Tween`-chain | If the D-14 charge-up→reveal sequence stays simple (one glow tween + one particle burst + one sprite swap), a `Tween`-chain is simpler to iterate on; use `AnimationPlayer` only if the sequence grows complex enough to want a visual timeline. |
| New `Settings.gd` autoload | Static class members on `UiStyle.gd` or a Control singleton pattern | An autoload is simplest for cross-scene access (Game.tscn's Juice/shake code needs to read the shake setting) — recommend a small new autoload registered in `project.godot`. |
| Two new AudioServer buses ("Music", "SFX") routed from `Music.gd`/`Sfx.gd` | A single shared linear-multiplier variable read by each `_play()` call, no bus changes | Bus-based volume is the idiomatic Godot mechanism, decouples volume control from playback code, and is simpler to reason about (`AudioServer.set_bus_volume_db` once vs. multiplying every play call) — **recommend creating the buses.** |

**Installation:**
```bash
# No package manager applies — GDScript, no npm/pip, no addons/ folder exists in this project.
# "Installing" this stack means creating a few new files/nodes and one project.godot line:
#
# autoloads/Juice.gd          -> register in project.godot [autoload]
# autoloads/Settings.gd       -> register in project.godot [autoload]
# scenes/vfx/                 -> new scene stubs (DamageNumber.tscn, etc.)
# Game.tscn                   -> add a persistent "FxLayer" Node2D child
# New audio buses "Music"/"SFX" under "Master" — create via Godot editor Audio panel,
#   which writes res://default_bus_layout.tres (does not currently exist in this project)
```

**Version verification:** No external packages are introduced by this phase — every recommendation above is a built-in Godot 4.6 engine API already available in this project's existing `4.6` / `GL Compatibility` feature set (confirmed via `project.godot` `config/features=PackedStringArray("4.6", "GL Compatibility")`). No `npm view`/`pip index`/`cargo search` equivalent applies.

## Package Legitimacy Audit

**Not applicable — this phase introduces zero external packages.** All new code is hand-rolled GDScript using built-in Godot 4.6 engine classes (`Tween`, `CPUParticles2D`, `Camera2D`, `AudioServer`, `Label`/`RichTextLabel`, `AnimationPlayer`). The project has zero entries in an `addons/` folder today and this phase should preserve that (`[VERIFIED: direct codebase read — no addons/ directory found]`). No package legitimacy gate is required.

**Packages removed due to [SLOP] verdict:** none (no packages considered).
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│  HOST PROCESS (own OS process)              CLIENT PROCESS(ES) (own OS     │
│                                                process each, separate       │
│                                                laptop, separate Camera2D)   │
├──────────────────────────────────────────────────────────────────────────── ┤
│  AUTHORITATIVE GAMEPLAY (unchanged this phase)                              │
│  Enemy._physics_process (AI, host-only)                                    │
│  Bullet._on_area_entered (host-only hit/damage)   ──MultiplayerSynchronizer │
│  Player.receive_damage / GameState.add_team_xp        20 Hz + explicit RPC │
│                                                     ──────────────────────▶ │
├──────────────────────────────────────────────────────────────────────────── ┤
│                    JUICE LAYER (THIS PHASE) — per-process, cosmetic only    │
│                                                                              │
│   Already-replicated field changes           Despawn / new-payload events  │
│   (current_hp, health, is_downed,            (death burst, big-hit,        │
│    evolution_stage, shield_active,            widened revive-progress)     │
│    dash_invincible, is_picking_card)                                       │
│         │                                              │                   │
│         ▼  Pattern A: diff-watch in _process()          ▼ Pattern B: small  │
│   (extends existing _last_hp_seen /                RPC (authority/any_peer,│
│    _last_health_seen idiom — ZERO new RPCs)          call_local) carrying   │
│         │                                          position/id — every    │
│         │                                          peer independently     │
│         │                                          plays its own reaction │
│         └───────────────────┬──────────────────────────┘                  │
│                              ▼                                             │
│                 ┌─────────────────────────┐                                │
│                 │   Juice.gd (NEW autoload)│  ← local execution facade     │
│                 │  shake / hitstop scale /  │    (no RPCs of its own)      │
│                 │  damage numbers / flash /  │                             │
│                 │  particle-burst factory   │                             │
│                 │  reads Settings.gd for    │                             │
│                 │  shake intensity (D-08)   │                             │
│                 └──────────┬───────────────┘                              │
│                            ▼                                              │
│                 Persistent FxLayer node (NEW, under Game.tscn)             │
│                 — every transient VFX parents HERE, never to the          │
│                   dying enemy / consumed orb / triggering node            │
│                                                                              │
│   Pattern C: local "hitstop scale" float, read ONLY by cosmetic code       │
│   (camera shake decay, sprite flash tween, particle timestep) —           │
│   NEVER Engine.time_scale, NEVER SceneTree.paused, NEVER read by           │
│   movement/AI/cooldown/RPC-dispatch code                                  │
└────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Notes |
|-----------|-----------------|-------|
| `Juice.gd` (new autoload) | Local, non-networked execution of every cosmetic effect: screen shake (own camera only), opt-in hitstop scale, floating damage numbers, hit-flash tweens, one-shot particle bursts | No RPCs of its own in the common case — called directly by code that already runs on every peer |
| `Settings.gd` (new autoload) | Holds shake intensity enum (off/low/normal) + music/sfx volume floats; applies to `AudioServer` bus volumes; exposes `shake_multiplier()` read by `Juice.gd` | Per-client, never synced (D-10); in-memory only (no persistence per Claude's discretion) |
| `GameEvents.gd` (existing, extended) | Add `big_hit(pos: Vector2)` signal + `emit_big_hit` RPC, mirroring existing `emit_hud`/`emit_driver_mode` `@rpc("authority","call_local","reliable")` pattern | Extend, don't fork into a parallel signal bus |
| `scenes/vfx/` (new folder) | Centralized, parametrized particle/flash/floating-text builders | Replaces the two near-duplicate `CPUParticles2D` builders already in `Player.gd` |
| `Enemy.gd` (modified) | Add `is_burning`/`is_slowed` replicated booleans + `_process` read-side tint/particle trigger; death-burst RPC call inside `take_damage()` before `queue_free()`, or via `_exit_tree()` hook; hp-diff hook calls `Juice.gd` in addition to `Sfx.hit()` | See Status-Effect Visibility Gap section below |
| `Enemy.tscn` (modified) | `SceneReplicationConfig` gains two new `properties/N` entries (`is_burning`, `is_slowed`) alongside the existing `position`/`current_hp`/`state` | Confirmed current config only has 3 properties — see Pitfall/Fix section below |
| `Player.gd` (modified) | health-diff → hit-flash/shake (local player only for shake) + ghost-chip HP animation; `is_downed` diff → collapse anim (all peers); `evolution_stage` → charge-up/reveal transform reacting to existing RPC; `dash_invincible`/`shield_active` diffs → ability juice | Reuses the exact `_last_health_seen` idiom already in the file |
| `XpOrb.gd` (modified) | Local magnetism/dart-to-bar tween (per-peer, non-authoritative), wider detection radius | Actual collection RPC (`_request_collect`) untouched |
| `PlayerHUD.gd` (modified) | Decouple displayed XP bar value from the true replicated `xp`; animate/pulse only when the local dart-flight tween completes | Pure presentation-layer change |
| `Game.gd` (modified) | Widen `_update_revive_bar`/`Player.set_revive_progress` from `rpc_id`-single-target to a broadcast; add `GameEvents.emit_big_hit.rpc(pos)` call inside `notify_significant_hit()`; add persistent `FxLayer` node reference | Small, surgical changes — Player nodes are confirmed named deterministically (`Player_%d`), unlike Enemy/Bullet |
| `CardOverlay.gd`/`.tscn` (modified) | Add `UiStyle` comic restyle calls (currently has ZERO) + pop/scale-in entrance tween (currently has none) | Fully greenfield within this file for both D-12 and PROG-02 |
| `MainMenu.gd`/`.tscn` (modified) | Add a "Settings" button that opens a new comic-styled sub-panel with shake cycle + 2 volume sliders | Currently has zero settings UI — confirmed via direct scene-tree read |

## Recommended Project Structure

```
autoloads/
├── Juice.gd                # NEW — local juice execution engine
├── Settings.gd              # NEW — client-only settings (shake intensity, volumes)
├── GameEvents.gd             # MODIFIED — add big_hit(pos) signal + RPC
├── Sfx.gd                    # MODIFIED — bus reassigned "Master" → "SFX"
├── Music.gd                  # MODIFIED — bus reassigned "Master" → "Music"
scenes/
├── vfx/                      # NEW folder
│   ├── DamageNumber.tscn/.gd     # floating combat text (pooled)
│   ├── HitFlash.gd                # tween-based white/color flash helper
│   └── ImpactBurst.gd             # parametrized CPUParticles2D one-shot factory
├── Player.gd                 # MODIFIED — hook points added, no structural rewrite
├── enemies/Enemy.gd          # MODIFIED — is_burning/is_slowed, death-burst RPC hook
├── enemies/Enemy.tscn         # MODIFIED — SceneReplicationConfig +2 properties
├── pickups/XpOrb.gd           # MODIFIED — magnetism + dart-to-bar tween
├── ui/CardOverlay.gd/.tscn    # MODIFIED — comic restyle + pop-in (D-12, PROG-02)
├── ui/MainMenu.gd/.tscn       # MODIFIED — Settings sub-panel (D-08/D-09)
├── ui/PlayerHUD.gd            # MODIFIED — decoupled bar-fill animation
Game.tscn                     # MODIFIED — new persistent "FxLayer" Node2D child
Game.gd                       # MODIFIED — revive-progress broadcast, big-hit RPC call site
default_bus_layout.tres        # NEW — "Music" and "SFX" buses under "Master"
```

### Pattern A: Local-Reactive State-Diff Juice (preferred default)

**What:** In a `_process()` already running identically on every peer, keep a `_last_seen_X` value and compare to the live already-replicated field each frame. On change, call a local `Juice.gd` helper. No RPC.

**When to use:** Any effect reacting to a value already part of `MultiplayerSynchronizer` replication or an already-broadcast RPC: `health`, `current_hp`, `is_downed`, `evolution_stage`, `xp`/`level`, `shield_active`, `dash_invincible`, `is_picking_card`, and (after the fix) `is_burning`/`is_slowed`.

**Example (extending the confirmed-live idiom in `Enemy.gd`):**
```gdscript
# Source: pattern already live at scenes/enemies/Enemy.gd:106-116, extended for this phase
func _process(_delta: float) -> void:
    if has_node("HealthBar"):
        $HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
    if current_hp < _last_hp_seen:
        var dmg := _last_hp_seen - current_hp
        Sfx.hit()
        Juice.spawn_damage_number(global_position, dmg, _damage_number_color())
        Juice.flash(self)  # white hit-flash, purely local, D-04
    _last_hp_seen = current_hp
    # ABIL-01 fix: react to the newly-replicated status flags (see Enemy.tscn change below)
    if is_burning and modulate != Color(1.0, 0.6, 0.2):
        modulate = Color(1.0, 0.6, 0.2)
    elif is_slowed and modulate != Color(0.5, 0.7, 1.0):
        modulate = Color(0.5, 0.7, 1.0)
    elif not is_burning and not is_slowed and modulate != Color.WHITE:
        modulate = Color.WHITE
```

### Pattern B: RPC-Broadcast Trigger + Independent Local Execution

**What:** Host calls a small `@rpc("authority", "call_local", "reliable")` method (mirrors `GameEvents.emit_hud`) carrying only the minimal payload. Every peer independently calls its own local `Juice.gd` methods.

**When to use:** (1) No existing replicated field carries the needed data (exact hit position for `big_hit`), or (2) an existing mechanism is single-target `rpc_id` and now needs to reach all peers (`set_revive_progress`).

**Example (new "big hit" broadcast, COOP-05, D-16):**
```gdscript
# GameEvents.gd — extends the existing emit_hud pattern (autoloads/GameEvents.gd:21-23)
signal big_hit(pos: Vector2)

@rpc("authority", "call_local", "reliable")
func emit_big_hit(pos: Vector2) -> void:
    big_hit.emit(pos)
```
```gdscript
# Game.gd — inside notify_significant_hit(), alongside the existing emit_hud.rpc("suspension")
# call site confirmed at scenes/Game.gd:944-956
func notify_significant_hit() -> void:
    if not multiplayer.is_server():
        return
    # ... existing debounce logic unchanged ...
    GameEvents.emit_hud.rpc("suspension")
    # NEW: needs the hit player's position — pass it through as a new param, or look it up
    # by the sender's peer_id (multiplayer.get_remote_sender_id()) before this guard clears it.
```

**Example (widening `set_revive_progress` — COOP-02, confirmed current gap):**
```gdscript
# Player.gd — CURRENT signature (confirmed at scenes/Player.gd:984-988):
# @rpc("any_peer", "call_remote", "reliable")
# func set_revive_progress(progress: float) -> void: ...
# Game.gd CURRENT call site (confirmed at scenes/Game.gd:958-965):
# p.set_revive_progress.rpc_id(target_id, progress)   # ← reaches ONLY the target's own client

# FIX: change to a broadcast so every peer can draw a ring over the downed player.
# Player nodes are named deterministically "Player_%d" (confirmed scenes/Game.gd:673:
#   player.name = "Player_%d" % data["id"]), so a broadcast RPC targeting this node
# resolves correctly on every peer — unlike Enemy/Bullet (see Anti-Pattern 1 below).
@rpc("any_peer", "call_local", "reliable")
func set_revive_progress(progress: float) -> void:
    if has_node("ReviveBar"):
        $ReviveBar.visible = progress > 0.0
        $ReviveBar.value = progress * 100.0
    # D-18: every peer also draws the world-space progress ring around `self`, not just
    # the owning peer's local ReviveBar — this is what makes COOP-02 team-visible.
```
```gdscript
# Game.gd — call site changes from rpc_id(target_id, ...) to a plain broadcast:
p.set_revive_progress.rpc(progress)   # was: p.set_revive_progress.rpc_id(target_id, progress)
```

### Pattern C: Local Opt-In "Hitstop Scale" (never Engine.time_scale, never SceneTree.paused)

**What:** `Juice.gd` exposes a local timer/scale, decaying each frame. Only presentation-layer code reads it and multiplies its own local `delta`. Gameplay code never reads it.

**Example:**
```gdscript
# Juice.gd (new autoload) — illustrative sketch, exact constants are Claude's discretion (D-06 target: 60-80ms)
extends Node

var hitstop_timer: float = 0.0
const HITSTOP_TIME_SCALE: float = 0.06   # cosmetic feel only, NOT Engine.time_scale

func hitstop(duration: float) -> void:
    hitstop_timer = max(hitstop_timer, duration)   # don't shorten an already-longer hitstop

## Cosmetic systems call this INSTEAD OF delta directly. Never call from _physics_process
## gameplay code (movement, damage, cooldowns, AI, RPC dispatch).
func cosmetic_delta(delta: float) -> float:
    if hitstop_timer > 0.0:
        hitstop_timer -= delta
        return delta * HITSTOP_TIME_SCALE
    return delta
```

## Status-Effect Visibility Gap (ABIL-01) — confirmed via direct read this session

`Enemy.tscn`'s `SceneReplicationConfig` (SubResource, verified this session) contains exactly three replicated properties:
```
properties/0/path = NodePath(".:position")
properties/1/path = NodePath(".:current_hp")
properties/2/path = NodePath(".:state")
```
`modulate` is NOT in this list. `Enemy.apply_burn()`/`apply_slow()` and the countdown logic in `_tick_status_effects()` are called from `_physics_process`, which is disabled on clients via `set_physics_process(is_multiplayer_authority())` in `_ready()` (confirmed `scenes/enemies/Enemy.gd:53`). **This confirms the bug is real and currently live**: burn/slow tints only ever apply on the host's own screen.

**Fix (small, targeted, do before DMG-07 element hit VFX):**
1. Add two `var` fields to `Enemy.gd`: `var is_burning: bool = false` and `var is_slowed: bool = false`, written by the host-only `_tick_status_effects()`/`apply_burn()`/`apply_slow()` exactly where `modulate` is currently set directly.
2. Add two new entries to `Enemy.tscn`'s `SceneReplicationConfig`:
   ```
   properties/3/path = NodePath(".:is_burning")
   properties/3/spawn = true
   properties/3/replication_mode = 2
   properties/4/path = NodePath(".:is_slowed")
   properties/4/spawn = true
   properties/4/replication_mode = 2
   ```
3. Move the actual tint/particle *reaction* into `_process()` (already runs on all peers) reading the new replicated flags — gameplay math (burn DoT tick via `take_damage(5)`, slow's `speed_multiplier`) stays exactly where it is today, host-only.

## Anti-Patterns to Avoid

- **`Engine.time_scale` or `SceneTree.paused` for hit-stop:** Process-global; on host it throttles the authoritative simulation for every connected peer, on a client it desyncs local rendering from the un-synced `Bullet.gd` simulation. `SceneTree.paused` is already an established anti-pattern this codebase avoids for the card-pick overlay (W4 from Phase 6) — hit-stop must respect the same precedent.
- **RPC-targeting a dynamically-spawned `Enemy` or `Bullet` node directly:** These are named with `randi()` (`"Enemy_%d" % (randi() % 9999)`, `"Bullet_%d" % (randi() % 99999)`, confirmed at `scenes/Game.gd:773` and `:860`) — not seeded identically across peers, so the resulting node path is very likely different on every peer. Route any new juice broadcast through a stable-path node (`Game.gd`, `GameEvents`) or a deterministically-named `Player` node instead.
- **Putting juice logic inside authority-gated gameplay functions:** `Enemy.take_damage()` and `Bullet._on_area_entered()` both `return` early if `not is_multiplayer_authority()` — any visual side effect placed inside that guard is invisible on every client. Put the visual reaction in code that already runs on every peer (`_process`, `_ready`, `_exit_tree`, or an explicit `call_local` RPC).
- **One giant "VFX god function" duplicated per feature:** `Player.gd` already shows early signs of this (`_spawn_heal_particles`/`_spawn_driver_particles` are ~90% identical). Centralize the `CPUParticles2D` builder in `scenes/vfx/ImpactBurst.gd`.
- **Assuming Music/SFX buses already exist:** They do not — see Pitfall 7 below.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screen shake decay/falloff curve | A custom ad hoc "add offset, subtract every frame" shake | Trauma-accumulator technique (`trauma` clamped 0–1, decaying every frame, shake magnitude derived from `trauma^2`) | Standard technique (Squirrel Eiserloh's GDC talk; kidscancode/Shaggy Dev recipes) that naturally caps runaway magnitude from simultaneous multi-hits — exactly what SYS-02/DMG-03 need |
| Hit-stop / freeze-frame | `Engine.time_scale` dip + timer to restore it | Local per-peer cosmetic float (`Juice.hitstop()`/`cosmetic_delta()`) read only by presentation code | `Engine.time_scale` is process-global and breaks this project's un-synced bullet simulation across peers (Pitfall 1) |
| Particle bursts | `GPUParticles2D` (the "modern"/autocomplete-first option) | `CPUParticles2D` exclusively | `GPUParticles2D` silently fails to render under `gl_compatibility` (no error, no warning) |
| Damage-number readability at swarm volume | Spawning one `Label` per hit with no cap | Pooled fixed-size number-label set + aggregate repeat hits on the same target within a short window (~100ms) into one summed number | Uncapped spawning both costs frame time and produces unreadable overlapping numbers exactly when players most need clarity |
| Audio ducking for new stingers vs. routine hits | A custom priority/nuisance-scoring system this phase | Nothing needed this phase — SFX pairing is explicitly Phase 11 scope; this phase only needs the two new Music/SFX buses for the volume sliders | Scope discipline — don't build Phase 11's sound-pool priority scheme now |

**Key insight:** Every "juice" primitive in this domain (shake, hit-stop, particle pooling, cleanup) has a well-documented standard solution that a naive first attempt tends to get subtly wrong in exactly the way that only shows up under this game's actual load pattern (3 players × 6 weapons × swarm waves, or a real 15-minute soak). Build the shared, correct version once in the foundational wave.

## Common Pitfalls

### Pitfall 1: `Engine.time_scale` hit-stop desyncs this project's un-synced bullet simulation
**What goes wrong:** Setting `Engine.time_scale` on the host throttles every enemy's `_physics_process`/`NavigationAgent2D` globally, visible to all connected clients; on a client it throttles only that client's own `_process` (rendering/interpolation), causing remote entities to "jump"/rubber-band once the dip ends — because `Bullet.gd` has no `MultiplayerSynchronizer` and trusts identical wall-clock deltas across peers for its client-simulated flight path (confirmed: `Bullet._physics_process` runs unconditionally on every peer, `position += direction * SPEED * delta`).
**How to avoid:** Never call `Engine.time_scale =` anywhere in this project. Implement hit-stop as a local-only cosmetic effect (Pattern C above) decided once in `Juice.gd`.
**Warning signs:** Any new code containing the literal string `Engine.time_scale`; bullet trajectories visibly differing between host and client after a hit-stop-triggering kill; testing done only solo (invisible until a real 2nd peer is involved).
**Phase to address:** Foundational wave — before any consuming effect (combat feedback, evolution) uses hit-stop.

### Pitfall 2: `GPUParticles2D` silently fails under this project's `gl_compatibility` renderer
**What goes wrong:** `project.godot` pins `renderer/rendering_method="gl_compatibility"` (confirmed this session). This renderer lacks compute-shader support, which `GPUParticles2D` depends on — particles silently fail to emit, no error, no warning.
**How to avoid:** `CPUParticles2D` exclusively for every new effect. `[VERIFIED: direct codebase read — project.godot rendering section; zero GPUParticles2D usages found anywhere]`
**Warning signs:** An effect "looks fine in editor preview" but is invisible in the actual running/exported build.
**Phase to address:** Foundational wave — state the rule once so every subsequent wave inherits it.

### Pitfall 3/4: Death-burst-before-`queue_free()`; never parent transient VFX to the trigger source
**What goes wrong:** `Enemy.take_damage()` calls `queue_free()` immediately once `current_hp <= 0` (confirmed `scenes/enemies/Enemy.gd:151-160`, and `Boss.take_damage()` follows the identical pattern). A death-burst effect that relies on diffing `current_hp` next frame races the despawn — the node may already be gone. Any VFX added as a *child* of the dying Enemy is destroyed before its animation completes.
**How to avoid:** Capture `global_position` and fire an explicit RPC (or use `Enemy._exit_tree()`, which runs identically on every peer once the spawner-replicated `queue_free()` removes the node) BEFORE/independent of the node's destruction, parenting the burst to the persistent `FxLayer` — never to the enemy/bullet/orb triggering it. Mirrors the existing `_show_dash_shockwave`/`_show_earth_shockwave` precedent of adding rings to `Game`/`self`, never to a transient node.
**Phase to address:** Foundational wave (establish `FxLayer` + the rule); Combat Feedback wave is the first real consumer (death burst, DMG-06).

### Pitfall 5: Damage numbers, shake, and (already existing) sound pool break down under swarm volume
**What goes wrong:** Up to 3 players × 6 independently-timed weapons × swarm waves can produce dozens of hits/kills per second late in a loop. Naive per-hit spawning of number labels/uncapped shake becomes unreadable/nauseating exactly when players most need clarity — worse for the passive projected-demo audience than for the player with control input.
**How to avoid:** Pool damage-number nodes, aggregate rapid repeat hits on the same target within ~100ms into one summed number; trauma-accumulator shake (clamped, `trauma^2` falloff), tiered by hit significance (`from_elite` flag already exists at `Player.gd:744` and can drive magnitude tiers); scope shake to each peer's own local `Camera2D`, triggered only by that peer's own damage taken (not by every teammate's hit).
**Phase to address:** Foundational wave (shared pooling/trauma utilities) + Combat Feedback wave (first consumer, must design for volume from the start, not retrofit).

### Pitfall 6: Orphaned Tween/particle/label nodes accumulate over a real 15-minute loop
**What goes wrong:** Roughly 10 new effect types are added this phase. A developer copying only the "spawn + tween" half of a pattern and omitting the terminal `queue_free()`/`finished.connect()` leaves nodes in the tree permanently — invisible in short manual tests, compounding into real, measurable frame-rate degradation only near the end of a genuine full-length session.
**How to avoid:** Centralize spawn+cleanup in `Juice.gd`/`scenes/vfx/` helpers rather than ~10 ad hoc implementations. Always add a defensive backstop (`get_tree().create_timer(lifetime + 0.5).timeout.connect(node.queue_free)`) alongside the "proper" signal-based cleanup — `queue_free()` on an already-freed node is a documented safe no-op.
**Phase to address:** Foundational wave builds the pattern; a final pass before phase completion should soak-test node count on both host and client roles independently (even though the full Phase-11-style soak/swarm validation is out of this phase's scope, a lighter sanity check here catches gross leaks early).

### Pitfall 7 (NEW — confirmed this session): No Music/SFX audio buses exist yet
**What goes wrong:** CONTEXT.md D-09 assumes "Volume sliders drive the existing Music.gd/Sfx.gd autoloads via audio bus volume" — but `Sfx.gd` (`autoloads/Sfx.gd:21`) and `Music.gd` (`autoloads/Music.gd:34`) both hard-code every `AudioStreamPlayer.bus = "Master"`. No `default_bus_layout.tres` exists in this project (confirmed via filesystem search) — only the implicit default "Master" bus exists. A volume slider that calls `AudioServer.set_bus_volume_db()` on a non-existent "Music"/"SFX" bus index will silently do nothing or throw, and adjusting "Master" would also mute the other stream.
**How to avoid:** Create two new audio buses ("Music", "SFX") routed to "Master" (via the Godot editor's Audio panel, which writes `default_bus_layout.tres`, or by constructing the resource programmatically), then change `Music.gd`'s `_player.bus = "Master"` → `"Music"` and `Sfx.gd`'s pool `p.bus = "Master"` → `"SFX"`. Only then do the Settings-panel sliders call `AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(slider_value))` (and equivalent for "SFX").
**Warning signs:** Volume sliders that appear to do nothing at runtime, or that also affect the other audio stream.
**Phase to address:** Foundational wave, alongside the shake-intensity Settings.gd work (D-08/D-09/D-10/D-11) — this is a small, self-contained, zero-dependency fix that should not be discovered mid-wave-1 as a surprise blocker.

## Code Examples

### XP orb magnetism + dart-to-bar (PICK-01/PICK-02, D-15)
```gdscript
# XpOrb.gd — NEW _process, purely cosmetic (real collection stays in _request_collect, untouched)
# Source: pattern derived from ARCHITECTURE.md "ghost-clone flight" recommendation
const MAGNET_RADIUS: float = 90.0
const MAGNET_SPEED: float = 260.0
var _magnetized: bool = false

func _process(delta: float) -> void:
    if _collected or _magnetized:
        return
    var nearest: Node = _find_nearest_player()
    if nearest == null:
        return
    if global_position.distance_to(nearest.global_position) <= MAGNET_RADIUS:
        _magnetized = true
    # purely cosmetic drift toward the nearest player — real collection RPC is unaffected;
    # body_entered still fires the existing _on_body_entered → _request_collect flow.
```

### Widened settings-driven audio bus volume
```gdscript
# Settings.gd (new autoload)
func set_music_volume(v: float) -> void:
    var idx := AudioServer.get_bus_index("Music")
    if idx >= 0:
        AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))

func set_sfx_volume(v: float) -> void:
    var idx := AudioServer.get_bus_index("SFX")
    if idx >= 0:
        AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `set_revive_progress` single-target `rpc_id` | Broadcast `.rpc()` to all peers | This phase (COOP-02) | Revive progress ring becomes team-visible per D-18/D-17 |
| Burn/slow tint set directly via host-only `modulate` write | Replicated `is_burning`/`is_slowed` booleans read in client-safe `_process()` | This phase (ABIL-01) | Fixes a genuine pre-existing client-visibility bug before it's inherited by new element VFX |
| `Sfx.gd`/`Music.gd` both on implicit "Master" bus | Two dedicated "Music"/"SFX" buses | This phase (DMG-08 settings support) | Enables independent volume control without needing per-call multiplier plumbing |
| `CardOverlay.gd` — no styling, instant show | Comic-restyled + pop/scale-in entrance | This phase (D-12, PROG-02) | Aligns with the existing Comic UI Pass identity established across MainMenu/PlayerHUD |

**Deprecated/outdated:** None — this is additive work on an already-current stack (Godot 4.6, no legacy APIs involved).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `AnimationPlayer` vs. `Tween`-chain choice for the evolution "closure moment" sequence is left as Claude's discretion between two viable built-in approaches — no external verification performed on which "feels" better | Standard Stack / Alternatives Considered | Low — both are correct built-in Godot tools; the choice affects only implementation ergonomics, not correctness |
| A2 | Exact numeric constants (trauma decay rate, shake magnitude per intensity tier, hit-stop duration within 60-80ms target, damage-number pool size/aggregation window) are unset by design (explicitly Claude's discretion per CONTEXT.md) — this research does not propose final numbers, only the technique | Common Pitfalls / Code Examples | Low — CONTEXT.md explicitly delegates this to the planner/implementer; wrong-but-adjustable constants are cheap to tune post-hoc |
| A3 | Creating audio buses via a hand-authored `default_bus_layout.tres` (rather than requiring the Godot editor GUI) is assumed feasible for an autonomous/headless execution flow — not verified against this specific Godot 4.6 build's resource format this session | Pitfall 7 | Medium — if a hand-authored `.tres` fails to parse correctly, the planner should budget a `checkpoint:human-verify` step to confirm the bus layout in the editor once, or accept doing this one step via the Godot editor manually |

**If this table is empty:** N/A — see above; all other claims in this research are either `[VERIFIED: direct codebase read]` this session or `[CITED]`/`[VERIFIED]` from the pre-existing HIGH-confidence milestone research completed the same day.

## Open Questions

1. **Exact mechanism for authoring `default_bus_layout.tres` without the Godot editor GUI**
   - What we know: The resource format is a standard Godot `.tres` (Resource) file; bus layouts are typically authored via the editor's Audio panel, which then serializes to this file. Godot also loads a `default_bus_layout.tres` automatically if present at the project root.
   - What's unclear: Whether this session's execution environment can create/verify this resource file correctly without opening the editor once (headless or CI-driven Godot resource authoring for `AudioBusLayout` is less commonly documented than scene/script authoring).
   - Recommendation: Planner should include a small early task in the Foundational wave to create the two buses (either via a short editor session if available, or by hand-authoring the `.tres` using the standard `AudioBusLayout` resource schema) and verify with `AudioServer.get_bus_index("Music") >= 0` at runtime before building any dependent Settings-panel code.

2. **Whether `notify_significant_hit()` needs a position parameter added, or should look up the hit player's position via `multiplayer.get_remote_sender_id()`**
   - What we know: `Game.notify_significant_hit()` currently takes no parameters and is called via `rpc_id(1)` from the hit player's owning peer (or directly if host); the debounce/broadcast logic is confirmed at `scenes/Game.gd:944-956`.
   - What's unclear: The cleanest way to thread the hit position through for `GameEvents.emit_big_hit(pos)` without changing the existing RPC signature in a way that breaks the SUSPENSION debounce logic.
   - Recommendation: Either add an optional `Vector2` param to `notify_significant_hit()` (defaulting to `Vector2.INF` for backward-compat-in-spirit, though this project doesn't need strict compat) or resolve the sender's `Player` node via `multiplayer.get_remote_sender_id()` inside the existing function body before the debounce guard exits. Planner should pick one approach explicitly rather than leaving it ambiguous.

## Environment Availability

Skipped — this phase has no new external tool/service/runtime dependencies. Godot 4.6 (`GL Compatibility` feature set) is the existing, already-validated engine for this project across 9 prior phases; no new CLI tools, databases, or services are introduced. The one new "environment" consideration (audio bus authoring) is addressed as Open Question 1 above, not a missing-dependency gap.

## Security Domain

`security_enforcement` is not explicitly disabled in `.planning/config.json`, so this section is included per protocol, scoped appropriately for a LAN-only, non-adversarial demo context (confirmed in the milestone `PITFALLS.md`: "This is a friendly LAN demo (not adversarial)").

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth system exists or is introduced (LAN-only, no accounts) |
| V3 Session Management | No | No session/token concept in this multiplayer model |
| V4 Access Control | Yes (narrow) | Every new juice-triggering RPC must keep host-side authority checks exactly like existing code: new/widened RPCs (`emit_big_hit`, widened `set_revive_progress`) must only ever be *originated* by the host (or validated host-side before broadcast) — clients must remain recipients only, never originators, mirroring the existing damage/health authority model |
| V5 Input Validation | Yes (narrow) | Any RPC parameter added this phase (e.g., a `Vector2 pos` for `emit_big_hit`) should be sanity-bounded server-side if ever accepted from a client-originated call path (in this phase's design, it is host-originated only, so this is a design constraint to preserve, not a new validation routine to build) |
| V6 Cryptography | No | Not applicable — no new secrets/crypto surface |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A buggy (not necessarily malicious) client spamming a juice-trigger RPC in a tight loop, degrading performance for the whole LAN session | Denial of Service | Keep juice-triggering authority host-side wherever the underlying game event is already host-authoritative (enemy death, damage, evolution) — clients should only ever be recipients of juice RPCs, never originators, per the existing damage/health authority model already enforced throughout this codebase |
| RPC-targeting a dynamically-spawned node whose name isn't deterministic across peers | Tampering (unintentional, not adversarial) | Route all new broadcasts through stable-path nodes (`Game.gd`, `GameEvents` autoload) or deterministically-named `Player_%d` nodes only — never `Enemy_%d`/`Bullet_%d` (see Anti-Patterns above) |

## Sources

### Primary (HIGH confidence)
- Direct codebase reads this session (`[VERIFIED: direct codebase read]`): `scenes/enemies/Enemy.gd`, `scenes/enemies/Enemy.tscn` (SceneReplicationConfig), `scenes/Player.gd`, `scenes/Game.gd` (both halves, ~1360 lines), `scenes/projectiles/Bullet.gd`, `scenes/pickups/XpOrb.gd`, `scenes/ui/PlayerHUD.gd`, `scenes/ui/UiStyle.gd`, `scenes/ui/CardOverlay.gd`, `scenes/ui/CardOverlay.tscn` (node tree), `scenes/ui/MainMenu.gd`, `scenes/ui/MainMenu.tscn` (node tree), `autoloads/GameEvents.gd`, `autoloads/GameState.gd`, `autoloads/Sfx.gd`, `autoloads/Music.gd`, `scenes/roles/HealDrone.gd`, `scenes/enemies/EliteEnemy.gd`, `scenes/enemies/Boss.gd` (partial), `project.godot`, `.planning/config.json`
- `.planning/research/SUMMARY.md`, `ARCHITECTURE.md`, `PITFALLS.md`, `STACK.md`, `FEATURES.md` — full milestone-level research completed same day (2026-07-13), HIGH confidence, grounded in the same direct-codebase-reading methodology plus official Godot 4.6 docs
- `.planning/phases/10-juicy-feedback-visual-gameplay-polish/10-CONTEXT.md` — locked user decisions (D-01 through D-20)
- `.planning/ROADMAP.md` §Phase 10 — 27 requirements, 6-wave suggested sequencing, extensive pitfall watch
- `.planning/REQUIREMENTS.md` §v1.1 — full requirement text

### Secondary (MEDIUM confidence, inherited from milestone research)
- Godot 4.6 official docs — `GPUParticles2D`, `Engine`, `Tween`, `SceneTree` class references: https://docs.godotengine.org/en/4.6/
- Godot official docs — Pausing games and process mode: https://docs.godotengine.org/en/latest/tutorials/scripting/pausing_games.html
- Godot official article — Multiplayer in Godot 4.0: Scene Replication: https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/
- [Screen Shake :: Godot 4 Recipes (kidscancode)](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html); [Bite-sized Godot: Better screen shake (Shaggy Dev)](https://shaggydev.com/2022/02/23/screen-shake-godot/)

### Tertiary (LOW confidence, inherited from milestone research — flagged as such there too)
- Individual Godot forum threads on `Engine.time_scale`/timer interaction quirks (community reports, not resolved to one canonical documented answer)
- Fatshark Forums community discussion of Vermintide/Darktide revive-feedback design (single community thread)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every recommendation is a built-in Godot 4.6 API, cross-checked against direct reads of this exact project's current code and confirmed against official docs (inherited from same-day milestone research)
- Architecture: HIGH — diff-watch pattern, deterministic Player naming, non-deterministic Enemy/Bullet naming, and the revive-progress single-target gap are all directly verified in this session's codebase reads, not inferred
- Pitfalls: HIGH — all six inherited pitfalls plus the two new session-verified findings (audio bus gap, CardOverlay/MainMenu current blank-slate state) are grounded in direct reads
- New findings (audio bus gap, CardOverlay/MainMenu state): HIGH — confirmed via direct file reads and filesystem search this session, not assumption

**Research date:** 2026-07-13
**Valid until:** 30 days (stable domain — built-in engine APIs, no external dependencies to go stale; re-verify only if the project's Godot version or renderer choice changes)
