# Stack Research

**Domain:** Game-feel / "juice" polish milestone (v1.1 Juicy Feedback) for an existing Godot 4.6 LAN co-op roguelike (host-authoritative, ENet)
**Researched:** 2026-07-13
**Confidence:** HIGH (built-in engine APIs, verified against Godot 4.6 official docs) / MEDIUM (a few architecture-integration judgment calls, flagged explicitly below)

> **Note:** This file supersedes the Phase-0 `STACK.md` for the purposes of this milestone. The original core-engine stack (ENet, MultiplayerSynchronizer/Spawner, CharacterBody2D, NavigationAgent2D, TileMap, CanvasLayer HUD) is already built and validated — see `.planning/PROJECT.md` Validated Requirements. Nothing below changes or re-litigates that. This research covers ONLY what's needed for the new juice/game-feel features.

## Context that shapes every recommendation

Read directly from the repo before making any call:

- **Renderer:** `project.godot` pins `config/features=PackedStringArray("4.6", "GL Compatibility")` and `renderer/rendering_method="gl_compatibility"`. This is the single most important constraint for the particle/VFX recommendations below.
- **Existing juice idioms already in the codebase** (`scenes/Player.gd`, `scenes/enemies/Enemy.gd`, `autoloads/Sfx.gd`, `autoloads/GameEvents.gd`) — the new work should extend these, not replace them:
  - `CPUParticles2D` built ad hoc in GDScript (`_spawn_heal_particles`, `_spawn_driver_particles` in `Player.gd`) — no `GPUParticles2D` anywhere in the project.
  - A tiny pooled-`AudioStreamPlayer` autoload (`Sfx.gd`, 12-voice round robin, non-positional, quiet dB levels) — `Sfx.shoot()` / `Sfx.hit()` are called directly, no RPC involved.
  - A **"diff-watch" pattern** for reacting to already-networked state: `Enemy.gd._last_hp_seen` and `Player.gd._last_health_seen` compare replicated values frame-to-frame in `_process()` and fire local cues (`Sfx.hit()`, heal particles) **on every peer independently, with zero new RPCs**, because `current_hp`/`health` are already replicated via `MultiplayerSynchronizer`.
  - A **"visual-only RPC"** idiom for cosmetic broadcasts not already implied by synced state: `Player._show_dash_shockwave` is `@rpc("any_peer", "call_local", "unreliable_ordered")` and only ever touches visuals, never game state — this is the sanctioned way to add a *new* RPC for a shared cosmetic moment in this codebase.
  - `GameEvents.gd` is a pure signal-bus autoload (`@rpc("authority", "call_local", "reliable")`) already used to fire CarHUD indicators team-wide (e.g. `notify_significant_hit` → `emit_hud.rpc("suspension")`).
  - `is_downed`, `health`, `shield_active`, `dash_invincible`, `is_picking_card`, `evolution_stage` are all already-replicated per-player state — several requested juice moments (downed collapse, revive success, hit-flash, evolution transform trigger) can hang entirely off watching these, no new networking required.
  - `Bullet.gd` has **no `MultiplayerSynchronizer`** — every peer simulates bullet flight identically from baked spawn data; only the host's copy (`is_multiplayer_authority()`) actually applies damage/despawns on hit. This matters for exact per-hit VFX timing (see "Floating Damage Numbers" pattern below).
  - `XpOrb.gd` is a plain `Area2D` with **no `MultiplayerSynchronizer` and no `_physics_process`** — position is set once at spawn and never moves. This matters directly for "orb magnetism."
  - `PlayerHUD.gd.update_hud()` sets `bar.value` on the XP `ProgressBar` **instantly** — this is the exact spot that needs to change for "XP value updates only on arrival."

Given this, the "stack" for this milestone is overwhelmingly **built-in Godot 4.6 APIs plus a handful of new hand-rolled, reusable scripts** — not new packages or addons.

## Recommended Stack

### Core Technologies (built-in Godot 4.6 APIs)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `Tween` (`create_tween()`) | Godot 4.6 core | Procedural one-off animation: scale pop/squash-stretch, fade, position float, ring expand | Already the project's established juice tool (`_show_dash_shockwave` builds a `Tween` inline). Handles most "juice" needs (pop-in cards, floating numbers, magnetism ease, XP-bar catch-up) without new nodes. Supports `set_parallel()`, `set_trans()/set_ease()`, `tween_callback()`, and `Tween.set_ignore_time_scale(true)` (verified current in 4.6 docs) so UI juice can keep running smoothly through a hit-stop dip if desired. |
| `CPUParticles2D` | Godot 4.6 core | All new particle bursts: hit sparks, death burst, spawn-in poof, level-up burst, evolution stinger, pickup pop, elemental hit VFX | **Not** `GPUParticles2D` — see "What NOT to Use". Matches the existing project convention exactly (heal particles, Driver Mode sparkles already use `CPUParticles2D`), guarantees identical behavior across every laptop regardless of GPU/driver, and at this game's particle counts (dozens of short-lived particles per burst, not thousands) CPU cost is a non-issue. |
| `Engine.time_scale` + `SceneTree.create_timer(t, true, false, true)` | Godot 4.6 core | Hit-stop / freeze-frame on kills and big hits | `Engine.time_scale` scales the delta passed to **every** `_process`/`_physics_process` and `Timer`/`SceneTreeTimer` in the tree (verified in 4.6 `Engine.time_scale` docs) — there is no per-node opt-out via `process_mode`. **Implementation-critical detail (verified):** the timer that restores `time_scale` back to `1.0` must be created with `ignore_time_scale = true` (the 4th positional arg to `create_timer`, added specifically for this use case) — otherwise the restore timer itself gets slowed by the very dip it's meant to end, and a "0.06s hit-stop" turns into over a second of frozen game. |
| `Camera2D` (hand-rolled trauma shake) | Godot 4.6 core | Screen shake on hits/kills | Godot 4 has **no built-in shake API** on `Camera2D` (confirmed — every camera-shake resource found in the ecosystem is a hand-written addon/gist). Each `Player.tscn` already has its own `Camera2D`, enabled only for the local authority peer (`$Camera2D.enabled = is_multiplayer_authority()` in `Player._ready()`), so shake is naturally local/per-client with zero networking changes. |
| `AnimationPlayer` | Godot 4.6 core | The Evolution stage-transform "closure moment" specifically | Unlike per-hit juice (highly parametric, best done procedurally with `Tween`), the evolution transform is a **fixed, reusable, non-parametric sequence** (flash → burst → sprite swap → hold → release) that benefits from being laid out visually on a timeline and reused per role. Use `Tween` for ad hoc/parametric juice and `AnimationPlayer` for this one authored sequence — don't force one tool to do everything. |
| `Label` / `RichTextLabel` (world-space, spawned like `_show_dash_shockwave`'s ring) | Godot 4.6 core | Floating damage numbers, floating pickup text | No addon needed. Spawn as a sibling under the `Game` node (mirrors the existing `game.add_child(ring)` pattern in `_show_dash_shockwave`), `Tween` `position.y` upward + fade `modulate.a`, `queue_free()` on complete. `RichTextLabel` with BBCode gives per-element color (fire=orange, ice=blue, earth=green, matching the existing burn/slow tint convention) and crit-size scaling for free. |
| `AudioStreamPlayer` pool (extend `autoloads/Sfx.gd`) | Godot 4.6 core | Every paired sound cue | No new audio middleware needed at this scope. Add one method per juice moment to the existing pool (`Sfx.pickup()`, `Sfx.level_up()`, `Sfx.evolve()`, `Sfx.downed()`, `Sfx.revive_success()`, `Sfx.enemy_death()`, ...), same shape as the existing `Sfx.shoot()`/`Sfx.hit()`. Consider bumping `POOL_SIZE` from 12 to ~18-20 since busy fights will now trigger more simultaneous cues (hit tick + death burst + pickup + shake-worthy hit, same frame). |

### Supporting "Libraries" — new hand-rolled scripts to add (no external packages)

| File | Purpose | When to Use |
|------|---------|-------------|
| `autoloads/Juice.gd` (new autoload) | Facade bundling "particle burst + screen shake (if local) + floating text (if relevant) + `Sfx` call" behind one semantic function per moment: `Juice.enemy_hit(pos, amount, element)`, `Juice.enemy_death(pos)`, `Juice.player_hurt(amount)`, `Juice.level_up()`, `Juice.evolve(stage)`, `Juice.pickup(pos, kind)`, `Juice.downed()`, `Juice.revived()` | Central integration point for every juice moment. Prevents the current ad hoc "build a `CPUParticles2D.new()` inline" style (fine for 2 effects, unwieldy for the ~10 new effects this milestone adds) from sprawling across `Player.gd`/`Enemy.gd`/`XpOrb.gd`. Internally still just uses `CPUParticles2D`/`Tween`/`Sfx` — this is organization, not a new dependency. |
| `scenes/fx/CameraShake.gd` (new small script, child node of each `Camera2D`) | Trauma-based screen shake (`add_trauma(amount)`, decays each frame, offsets `camera.offset` via jitter/`FastNoiseLite`) | Attach under `Player.tscn`'s existing `Camera2D`. Guard trigger calls with `is_multiplayer_authority()` (matches the existing camera-enable guard) so only the local player's own camera ever shakes. |
| `scenes/fx/FloatingNumber.tscn` + tiny script | Reusable floating-text scene (`Label` + pre-wired `Tween` for float+fade) instantiated by `Juice.gd` | Damage numbers, XP-orb pop text, pickup text. One small scene instead of hand-building a `Label` from scratch at every call site. |
| Small preset dictionary inside `Juice.gd` (e.g. `const HIT_PRESETS := {"fire": {...}, "ice": {...}, "earth": {...}}`) | Per-element hit VFX (scorch/shatter/crack look) built from one shared `CPUParticles2D`-builder function parameterized by preset | Avoids writing 3 near-duplicate particle-construction functions; matches the existing burn=orange / slow=blue color convention already used for status-effect tinting in `Enemy.gd`. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Godot 4.6 editor (already in use) | Author `AnimationPlayer` tracks for the evolution sequence; tune `CPUParticles2D` presets visually before porting values into code presets | No new tooling needed. |

## Installation

No package manager applies (GDScript, no npm/pip, no addons folder currently exists). "Installing" this stack means creating a few new files and one autoload registration:

```
# New files to create — no addons/ folder, no AssetLib installs
autoloads/Juice.gd                       # register in project.godot [autoload]
scenes/fx/CameraShake.gd                 # attach as child script under each Player's Camera2D
scenes/fx/FloatingNumber.tscn            # small reusable Label+Tween scene
```

```ini
# project.godot — add one line under [autoload], after Music
Juice="*res://autoloads/Juice.gd"
```

No changes to `[rendering]` are needed or recommended — stay on `gl_compatibility` (see below).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `CPUParticles2D` for all new bursts | `GPUParticles2D` | Only if the project ever switches the renderer to Forward+/Mobile (Vulkan/Metal) — not planned, and not worth the renderer-compatibility risk this close to a fixed demo date on unknown laptop GPUs. |
| Hand-rolled `CameraShake.gd` (~40 lines) | A camera-shake or full camera-framework addon from the Asset Library (e.g. Phantom Camera-style tools) | If the team later wants cinematic follow/zoom/multi-camera features beyond shake — this project doesn't need any of that (one `Camera2D` per local player, static limits already implemented). Adding a full addon this late adds a Godot-4.6-compatibility unknown for a feature that's ~40 lines to hand-roll and fully understand/debug live during the demo. |
| Diff-watching already-replicated state (`_last_hp_seen`-style) for *most* juice | A new `@rpc(..., "call_local", ...)` per juice event (mirrors `_show_dash_shockwave`) | Use the RPC approach specifically where **per-event precision matters and diffing would blur events together** — see "Floating Damage Numbers" pattern below. Don't default to "add an RPC for every juice moment" — most of this milestone's moments (hit-flash, heal sparkle, downed/revived, HP-bar flash) already have a synced boolean/int to diff against for free. |
| `AnimationPlayer` for the evolution transform only | `Tween`-only for everything | If the evolution sequence stays simple enough (one flash + one burst), a `Tween` chain works fine too — `AnimationPlayer` is the *recommended*, not *required*, choice; pick it only if the sequence grows complex enough to want a visual timeline. |
| Ghost-clone cosmetic "flight" for XP orb magnetism (real collision/collection logic untouched, enlarge pickup radius slightly) | Fully host-authoritative synced orb magnetism (extend `XpOrb.tscn` with a `MultiplayerSynchronizer`, move `global_position` host-side in `_physics_process`, mirroring `Enemy.gd`) | **Recommend the ghost-clone approach for this milestone** — it requires zero new networked node state, reuses the existing instant `body_entered` → `_request_collect` RPC unchanged, and is safe to build under a demo deadline. Reserve true synced magnetism only if the team specifically wants pixel-accurate "orb visibly chases you with no fixed capture radius" behavior — it's the more "correct" simulation but adds real netcode surface (new synced property, new host-side `_physics_process`, new authority guard) for what is fundamentally a cosmetic ask. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `GPUParticles2D` for any new effect | The project's `renderer/rendering_method="gl_compatibility"` (GLES3/OpenGL) does not support compute shaders, which `GPUParticles2D`'s simulation depends on. The official 4.6 docs confirm `emit_particle()` is "only supported on the Forward+ and Mobile rendering methods, not Compatibility," and there's a multi-version history of GPUParticles2D visibility/emission bugs specifically on the Compatibility renderer (godotengine/godot#85945 targeted at the 4.3 milestone, #84072, #102634). Even where basic autostart emission does render on GLES3, it's been inconsistent enough across driver/GPU combinations to be a real risk across laptops of unknown hardware for a live demo. | `CPUParticles2D` — already proven working in this exact project, on this exact renderer, right now. |
| `GPUParticles2D`'s built-in "Trails" (`trail_enabled`) for the Speedster dash trail | Same compute-shader dependency as above. | A hand-rolled trail: either a `Line2D` tracking recent positions with per-point fading width/alpha, or periodic duplicated-sprite "afterimage" ghosts (`Sprite2D`/`AnimatedSprite2D.duplicate()`, `modulate.a` faded via `Tween`, `queue_free()` after ~0.2s) — both renderer-agnostic, both common in 2D indie dash-trail implementations. |
| `Engine.time_scale` combined with `await get_tree().create_timer(dur).timeout` (default args) to end a hit-stop | The default `create_timer` call is itself scaled by the very `time_scale` it's meant to restore, so a 0.06s dip at `time_scale = 0.05` would take ~1.2 real seconds to resolve — a frozen-feeling bug, not a snappy hit-stop. | `get_tree().create_timer(dur, true, false, true)` — 4th arg `ignore_time_scale = true` (verified current in 4.6 `SceneTree` docs). |
| A **new gameplay-affecting RPC per damage instance** just to display a number (e.g. "send `show_damage(amount)` RPC on every single hit") for *player-received* damage | `health` is already replicated via `MultiplayerSynchronizer`; adding parallel per-hit RPC traffic for something derivable from the diff is redundant network chatter and a second source of truth to keep in sync. | Diff-watch `health` in `_process()` exactly like the existing `_last_health_seen` cue does, and display the delta as the floating number. Accept the rare edge case where two hits inside one ~50ms sync tick (20 Hz) bundle into a single number — acceptable at this game's fire rates. |
| Third-party addons in general (Asset Library camera/tween/"juice" frameworks) | The project currently has **zero** entries in an `addons/` folder — everything is hand-rolled GDScript, deliberately (mirrors the existing "no third-party networking libraries" constraint in `PROJECT.md`). Introducing a new addon now adds a Godot-4.6-compatibility unknown (many popular shake/juice addons target 4.0-4.2 and aren't verified against 4.6) right before a fixed-date demo, for functionality that's small enough to hand-roll and fully own. | Hand-rolled scripts as listed above — small, debuggable, and consistent with the rest of the codebase. |
| `SceneTree.paused = true` (exempting a "juice" layer via `PROCESS_MODE_ALWAYS`) as the hit-stop mechanism | Works fine on a client, but if triggered on the **host**, it pauses the host's own `_physics_process` — which is where enemy AI, bullet movement, and `MultiplayerSynchronizer` replication live — turning a "brief local freeze-frame" into a genuine (if brief) freeze of the authoritative simulation for the whole team, with no way to exempt just the "visual" layer (`process_mode` only interacts with `SceneTree.paused`, not `Engine.time_scale`-style delta scaling). | Use `Engine.time_scale` deliberately and keep the dip **very short** (60-100ms). Treat the host-side "everyone briefly feels a hitch" side effect as acceptable, even fitting, for the "big hit"/kill shared moments the milestone explicitly wants broadcast — just don't fight it, and don't apply it for routine small hits (routine hits should stay non-freezing: hit-flash + shake only, no time_scale dip). |

## Stack Patterns by Variant

**If the juice moment is a reaction to state that's already replicated (health, current_hp, is_downed, shield_active, is_picking_card, evolution_stage):**
- Diff-watch it locally in `_process()` on every peer (exact pattern already in `Enemy._last_hp_seen` / `Player._last_health_seen`).
- Zero new RPCs. This covers: hit-flash, HP-bar flash, damage numbers on the *player* (self-damage), downed collapse animation, revive success burst, evolution-transform trigger, level-up burst trigger (`is_picking_card` flipping true).

**If the juice moment needs per-event precision that diffing would blur (rapid multi-hit bullets landing on the same enemy within one ~50ms sync tick):**
- Add a small `@rpc("any_peer"/"authority", "call_local", "unreliable_ordered")` visual-only function, called from the same host-authoritative code path that already applies the damage (`Bullet.gd._on_area_entered`, contact-damage code) — mirrors `_show_dash_shockwave` exactly. Bandwidth cost is trivial (a `Vector2` + `int`/`String`).
- This covers: precise per-hit damage numbers on **enemies** specifically (since multiple weapons/players can hit the same enemy in the same tick), enemy hit-VFX (fire scorch/ice shatter/earth crack), and — optionally — enemy death burst position, though the signal-connection trick below achieves the same thing for free.

**If the juice moment reacts to a networked node's lifecycle (enemy spawns in, enemy dies) rather than a scalar value:**
- Connect a **local** signal handler on each peer's own copy of the node right after the `MultiplayerSpawner` instances it (every peer's own `_ready()`/spawn callback runs identically): hook `tree_exiting` on `Enemy` instances to fire a local death-burst at `global_position` (still valid pre-removal) with zero new RPC, since `queue_free()` on the host already replicates removal to every peer's copy, which independently fires their own local `tree_exiting`.
- "Spawn-in" effects are even simpler: trigger directly inside `Enemy._ready()` — it already runs on every peer identically.

**If the juice moment would change what actually happens in the simulation (XP orb magnetism, anything that changes *when* a pickup is granted or *who* gets credit):**
- Treat it like enemy AI: either make it fully host-authoritative + synced (extend with a `MultiplayerSynchronizer`, mirror `Enemy.gd`), or — recommended for this milestone, see "Alternatives Considered" — keep the real collision/collection logic untouched and make the "flight" purely a decorative, non-gating ghost clone.
- Never let a purely local/per-peer cosmetic tween be the thing that determines whether XP is granted — that's the one place in this milestone where "local-only, no RPC" is the *wrong* default.

**If the juice moment is a UI-only value (XP bar display vs. the underlying networked `xp`/`level`):**
- `GameState._sync_team_xp` / `Player._update_xp_hud` already set `p.xp`/`p.level` and `bar.value` **instantly** on RPC arrival. Decouple the *displayed* bar value from the *authoritative* value: keep `xp`/`level` snapping instantly (no networking change), but change `PlayerHUD.update_hud()` to `Tween` the `ProgressBar.value` toward the new target over ~0.3-0.5s instead of assigning it directly. This alone delivers "XP value updates only on arrival" with zero new RPCs — no need to precisely choreograph it against a specific flying icon landing.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|------------------|-------|
| `CPUParticles2D`, `Tween`, `AnimationPlayer`, `Engine.time_scale`, `Camera2D` | Godot 4.6, `gl_compatibility` renderer | All core, renderer-agnostic APIs; stable since Godot 4.0, no 4.6-specific caveats found. |
| `GPUParticles2D` | **Not fully compatible** with the `gl_compatibility` renderer used by this project | `emit_particle()` explicitly unsupported on Compatibility per 4.6 docs; general emission has a multi-version history of Compatibility-renderer-specific bugs (#85945 targeted 4.3, #84072, #102634). Do not introduce for this milestone. |
| `SceneTree.create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)` | Godot 4.6 | 4-arg signature with `ignore_time_scale` confirmed current in 4.6 docs — required for correct hit-stop recovery timing. |
| `Tween.set_ignore_time_scale(bool)` | Godot 4.6 | Confirmed current API; default `false` (tweens are scaled by `Engine.time_scale` unless told otherwise). |

## Sources

- Godot 4.6 official docs, `GPUParticles2D` class reference — verified `emit_particle()` Compatibility-renderer restriction (HIGH confidence): https://docs.godotengine.org/en/4.6/classes/class_gpuparticles2d.html
- Godot 4.6 official docs, `Engine` class reference — verified `time_scale` behavior/scope (HIGH confidence): https://docs.godotengine.org/en/4.6/classes/class_engine.html
- Godot 4.6 official docs, `Tween` class reference — verified `set_ignore_time_scale` (HIGH confidence): https://docs.godotengine.org/en/4.6/classes/class_tween.html
- Godot 4.6 official docs, `SceneTree` class reference — verified `create_timer` 4-arg signature (HIGH confidence): https://docs.godotengine.org/en/4.6/classes/class_scenetree.html
- Godot 4.6 official docs, renderer comparison — confirmed Compatibility renderer has no compute-shader support (HIGH confidence): https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html
- Godot Engine official blog, "Progress report: state of particles and future updates" — general GPU-particle renderer support statement (MEDIUM confidence, doesn't address Compatibility specifically): https://godotengine.org/article/progress-report-state-of-particles/
- godotengine/godot GitHub issues — history of Compatibility-renderer GPUParticles2D bugs across 4.2-4.5 (MEDIUM confidence, individual bug reports rather than a definitive blanket statement): https://github.com/godotengine/godot/issues/85945, https://github.com/godotengine/godot/issues/84072
- WebSearch aggregation on Godot 4 camera-shake addons — confirms no built-in shake API exists; every result is a third-party hand-rolled script (MEDIUM confidence, community consensus rather than official docs): https://godotforums.org/d/32978-camera-shake-in-godot-4, https://gist.github.com/Alkaliii/3d6d920ec3302c0ce26b5ab89b417a4a
- Direct codebase reads (HIGH confidence, ground truth for this project): `C:\Users\morit\Rouge-Like\project.godot`, `scenes/Player.gd`, `scenes/enemies/Enemy.gd`, `scenes/projectiles/Bullet.gd`, `scenes/pickups/XpOrb.gd`, `autoloads/Sfx.gd`, `autoloads/GameEvents.gd`, `autoloads/GameState.gd`, `scenes/ui/PlayerHUD.gd`, `scenes/ui/CardOverlay.gd`

---
*Stack research for: Godot 4 game-feel/juice milestone (v1.1 Juicy Feedback), Rouge-Like project*
*Researched: 2026-07-13*
