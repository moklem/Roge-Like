# Architecture Research: Juicy Feedback Integration

**Domain:** Game-feel/juice layer for an existing Godot 4 host-authoritative co-op roguelike
**Researched:** 2026-07-13
**Confidence:** HIGH (grounded in direct reading of Player.gd, Enemy.gd, Bullet.gd, XpOrb.gd, GameEvents.gd, GameState.gd, Game.gd, project.godot) with MEDIUM-confidence Godot-engine-mechanics claims verified against official docs and community sources (cited below).

## Core Finding (read this first)

This codebase already contains a **proven, working pattern for "juice visible to everyone with zero new networking"**: several scripts run identical `_process()` logic on *every* peer and react to fields that are *already* replicated (`current_hp`, `health`, `is_downed`, `evolution_stage`, `shield_active`, `is_picking_card`). Two examples already ship in the repo:

- `Enemy.gd:_process` diffs `current_hp` against `_last_hp_seen` and calls `Sfx.hit()` **on every peer**, with no RPC at all.
- `Player.gd:_process` diffs `health` against `_last_health_seen` and spawns a green heal-particle burst **on every peer**, with no RPC at all — the comment literally says *"health is synced, so every peer sees the burst."*

This is the single most important architectural fact for this milestone: **most of the "visible to all players" requirements in the milestone spec (healing juice, downed collapse, revive success, evolution transform) are already solvable by extending this exact pattern — no new RPCs required.** The only things that genuinely need new broadcast messages are (a) a continuous, currently single-target value that needs to become team-visible (revive progress ring), and (b) an effect that needs positional data the existing broadcast channel doesn't carry (a "big hit" burst at a specific world position, since `GameEvents.emit_hud` only carries an event-name string).

The second most important fact: **`Engine.time_scale` and `get_tree().paused` are both wrong tools for hit-stop in this architecture**, and must not be used. Full reasoning in "Hit-Stop Scoping" (Pattern C), below.

---

## System Overview

```
┌───────────────────────────────────────────────────────────────────────────┐
│  HOST PROCESS                                    CLIENT PROCESS(ES)       │
│  (own OS process, own Engine singleton)          (own OS process, own     │
│                                                    Engine singleton)       │
├───────────────────────────────────────────────────────────────────────────┤
│  Authoritative gameplay                                                    │
│  Enemy._physics_process (AI)     ──replicate──▶  position/current_hp      │
│  Bullet._on_area_entered (hit)   ──RPC/replicate─▶ is_downed/xp/level/... │
│  GameState.add_team_xp/attempt_revive  ─RPC──▶   (MultiplayerSynchronizer │
│                                                    ~20 Hz + explicit RPCs) │
├───────────────────────────────────────────────────────────────────────────┤
│                     JUICE LAYER (this milestone) — per-process, cosmetic   │
│  ┌─────────────────────────────┐   ┌─────────────────────────────┐       │
│  │ Pattern A: LOCAL-REACTIVE    │   │ Pattern B: RPC-TRIGGERED     │       │
│  │ Diff an already-replicated   │   │ Host broadcasts a small      │       │
│  │ field in _process(); every   │   │ event (authority,call_local);│       │
│  │ peer independently plays its │   │ every peer independently     │       │
│  │ own local VFX/SFX from it.   │   │ plays its own local VFX/SFX. │       │
│  │ No new network traffic.      │   │ New network message, but     │       │
│  │                               │   │ tiny payload (pos/id/amount).│       │
│  └───────────────┬───────────────┘   └───────────────┬───────────────┘     │
│                  └───────────────┬───────────────────┘                    │
│                                  ▼                                        │
│                    ┌───────────────────────────┐                          │
│                    │      JuiceManager          │  ← NEW autoload         │
│                    │  (pure local execution:    │                        │
│                    │   shake, hitstop, damage    │                        │
│                    │   numbers, flash, bursts)   │                        │
│                    │  NEVER touches Engine.      │                        │
│                    │  time_scale / tree.paused   │                        │
│                    └───────────────────────────┘                          │
└───────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Notes |
|-----------|----------------|-------|
| `JuiceManager` (new autoload) | Local, non-networked execution of every cosmetic effect: screen shake (own camera only), opt-in hitstop scale, floating damage numbers, hit-flash tweens, one-shot particle bursts | Has **no RPCs of its own** in the common case — it is called directly by scripts that already run on every peer (Enemy._process, Player._process, etc.) |
| `GameEvents` (existing autoload) | Broadcast channel for *discrete named events* and now also *positional* big-hit events | Extend, don't replace — mirrors existing `emit_hud`/`emit_driver_mode` pattern |
| `Enemy.gd` (modified) | Add death-burst hook in `_exit_tree()`, add synced status booleans for burn/slow so element VFX shows on all peers, hp-diff hook calls `JuiceManager` instead of only `Sfx.hit()` | See "Status-effect visibility gap" below — genuine pre-existing bug this milestone should fix |
| `Player.gd` (modified) | health-diff → hit-flash/shake (local player only for shake), `is_downed` diff → collapse anim (all peers), evolution_stage → transform VFX (all peers, camera-affecting parts gated to owner) | Reuses the exact `_last_health_seen` idiom already in the file |
| `XpOrb.gd` (modified) | Local magnetism/fly-toward tween (per-peer, non-authoritative), wider detection radius | Actual collection RPC (`_request_collect`) is untouched |
| `PlayerHUD` / HUD script (modified) | Decouple *displayed* XP bar value from the *true* replicated `xp`/`team_xp`; only animate the bar up when an orb's local fly-animation completes | Pure presentation-layer change |
| `Game.gd` (modified) | Widen `set_revive_progress` from `rpc_id(target_id, …)` to a broadcast (`.rpc()`), so every peer can draw a ring over the downed player, not just their own screen | Small, surgical change — Player nodes have **deterministic** cross-peer names (`Player_%d`), unlike Enemy/Bullet, so this is safe |

---

## Recommended Project Structure

```
autoloads/
├── JuiceManager.gd        # NEW — local juice execution engine (see Pattern 3 below)
├── GameEvents.gd           # MODIFIED — add `big_hit(pos: Vector2)` signal + RPC
scenes/
├── vfx/                    # NEW folder — small reusable juice scenes
│   ├── DamageNumber.tscn/.gd   # floating combat text (pooled or self-freeing, mirrors
│   │                            #   Player._spawn_heal_particles' self-free convention)
│   ├── HitFlash.gd             # tiny helper: tween-based white/color flash on a CanvasItem
│   └── ImpactBurst.gd          # parametrized CPUParticles2D one-shot factory (replaces the
│                                #   two near-duplicate particle builders already in Player.gd)
├── Player.gd                # MODIFIED — hook points added, no structural rewrite
├── enemies/Enemy.gd         # MODIFIED — _exit_tree death burst, synced status flags
├── pickups/XpOrb.gd         # MODIFIED — magnetism tween
Game.gd                      # MODIFIED — revive-progress broadcast, big-hit RPC call site
```

### Structure Rationale

- **`autoloads/JuiceManager.gd`:** Sits alongside `Sfx.gd`/`GameEvents.gd` because it plays the same architectural role — a small, stateless-ish helper every scene can call into. Keeping it a *pure local* autoload (no authority checks, no RPCs) makes it trivially safe to call from anywhere, including inside code that already runs on every peer.
- **`scenes/vfx/`:** The codebase currently duplicates CPUParticles2D construction inline in `Player.gd` (`_spawn_heal_particles`, `_spawn_driver_particles` — two nearly-identical ~15-line builders). This milestone adds several more particle moments (death burst, level-up burst, evolution burst, pickup pop, dash trail). Centralizing the builder avoids a fourth/fifth copy-paste and gives one place to tune performance (see Scaling Considerations).
- **No new autoload for "CombatEvents":** it's tempting to add one, but `GameEvents` already exists for exactly this purpose (broadcast, no state) — extend it instead of fragmenting the signal-bus pattern.

---

## Architectural Patterns

### Pattern A: Local-Reactive State-Diff Juice (preferred default)

**What:** In a `_process()` that already runs identically on every peer, keep a `_last_seen_X` value and compare it to the live (already-replicated) field each frame. On a meaningful change, call a local `JuiceManager` helper. No RPC, no new network message.

**When to use:** Any juice effect that reacts to a value that is *already* part of `MultiplayerSynchronizer` replication or an *already-broadcast* RPC: `health`, `current_hp`, `is_downed`, `evolution_stage`, `xp`/`level`, `shield_active`, `dash_invincible`, `is_picking_card`.

**Trade-offs:**
- Zero new network traffic, zero new RPC surface to get wrong, trivially safe (this is exactly today's proven pattern).
- Automatically "visible to all players" — every peer's copy of the diff logic fires independently and locally.
- Granularity is capped by replication tick rate (~20 Hz / 50 ms per PROJECT.md). If multiple discrete events land inside one sync interval (e.g. Fire Burst's 3–5 simultaneous bolts hitting the same enemy), the diff only sees the *net* change and cannot distinguish "one hit for 100" from "five hits for 20 each." For a floating-damage-number feature this means: **numbers are correct in total but may under-count how many separate numbers pop.** Acceptable for a demo; flag as a known limitation, not a blocker.

**Example (extending the existing idiom in `Enemy.gd`):**
```gdscript
func _process(_delta: float) -> void:
    if has_node("HealthBar"):
        $HealthBar.value = float(current_hp) / float(MAX_HP) * 100.0
    if current_hp < _last_hp_seen:
        var dmg := _last_hp_seen - current_hp
        Sfx.hit()
        JuiceManager.spawn_damage_number(global_position, dmg, Color.WHITE)
        JuiceManager.flash(self)              # hit-flash, purely local
    _last_hp_seen = current_hp
```

### Pattern B: RPC-Broadcast Trigger + Independent Local Execution

**What:** Host calls a small `@rpc("authority", "call_local", "reliable")` method (mirrors `GameEvents.emit_hud`) carrying only the minimal payload (event name, or `Vector2` position, or a target peer id). Every peer's handler independently calls its own local `JuiceManager` methods. **This is not a shared/synchronized simulation — it is "everyone gets told the same moment happened, and each renders their own local reaction."**

**When to use:** Only when (1) no existing replicated field carries the needed information (e.g. exact hit *position* for a world-space burst — `emit_hud` only has a string), or (2) an existing mechanism is a single-target `rpc_id` and the milestone now requires all peers to see it (revive progress ring).

**Trade-offs:**
- Full fidelity, no replication-tick granularity loss, correct even under bursty simultaneous hits.
- New RPC = new thing that can be gotten wrong. **Critical constraint discovered in this codebase:** never target a per-node RPC at a dynamically-spawned `Enemy` or `Bullet` node directly (see Anti-Pattern below) — route through a stable-path node (`Game.gd` at `/root/Game`, or the `GameEvents` autoload).

**Example (new "big hit" broadcast, extending the existing `GameEvents` idiom):**
```gdscript
# GameEvents.gd
signal big_hit(pos: Vector2)

@rpc("authority", "call_local", "reliable")
func emit_big_hit(pos: Vector2) -> void:
    big_hit.emit(pos)
```
```gdscript
# Game.gd — inside notify_significant_hit(), alongside the existing emit_hud.rpc("suspension")
GameEvents.emit_big_hit.rpc(hit_player.global_position)
```
Every peer's own listener (wherever it lives) then calls `JuiceManager.burst(pos, BIG_HIT_CONFIG)` and, if the *local* player was the one hit, additionally `JuiceManager.shake(...)`.

### Pattern C: Local Opt-In "Hitstop Scale" (never Engine.time_scale, never SceneTree.paused)

**What:** `JuiceManager` exposes a local timer/scale (e.g. `hitstop_amount: float`, decaying each frame). Only **presentation-layer** code explicitly reads it and multiplies its own local `delta` before use (camera-shake update, sprite flash tween step, particle burst timestep, floating-number tween). **Gameplay code — `_physics_process` on Player/Enemy, RPC dispatch, ability cooldown timers, XP/health mutation — never reads it and is completely unaffected.**

**When to use:** Every hit-stop/freeze-frame moment in this milestone (kill hit-stop, big-hit impact, evolution "closure" slow-mo).

**Why not the two obvious alternatives — this directly answers the hit-stop scoping question:**

1. **`Engine.time_scale` is process-global, not networked** — but that's exactly the problem, not a non-issue. Each of the up-to-3 LAN players is a **separate OS process** (separate laptop), so `Engine.time_scale` is never itself transmitted over ENet. But:
   - If the **host** sets `Engine.time_scale` (even briefly, even to something like 0.05), it throttles the host's own `_physics_process`, which is where `Enemy.gd`'s AI, navigation, and status-effect ticking live (`set_physics_process(is_multiplayer_authority())` — host-only). Since enemy position/HP are then replicated outward from this now-slow-motion host simulation, **every connected client sees the whole world slow down/freeze**, not just the player who scored the kill. This is precisely the failure mode the milestone context warns about.
   - If a **client** sets its own `Engine.time_scale`, it doesn't touch the host's simulation at all, but it throttles that client's *own* `_process`, which is what drives rendering/animation/interpolation of the incoming replicated state for everyone else. The network keeps delivering real-time updates on schedule while the client's local frame budget is scaled down — the visible symptom is remote entities appearing to "jump" or rubber-band once the local timescale dip ends, an artifact of the renderer falling behind live network state, not a gameplay bug, but a bad *feel* bug (ironic, for a juice feature).
   - Verdict: **do not use `Engine.time_scale` for hit-stop in this project**, on either host or client.
2. **`get_tree().paused = true` is already an established anti-pattern in this codebase.** The existing card-pick/level-up overlay deliberately avoids pausing the SceneTree ("never pauses SceneTree, per an established pitfall") specifically so other players and the network keep running while one player is on a local UI screen. Hit-stop must respect the same precedent — pausing (even with `PROCESS_MODE_ALWAYS` exceptions for camera/particles) reintroduces the exact class of problem this project already decided to avoid, and adds complexity (per-node process-mode auditing) that a simple local float does not.
3. **Recommended implementation:** a plain autoload float, read only by opt-in cosmetic code. This has zero engine-level side effects, cannot desync anything (it isn't state at all, let alone replicated state), and trivially satisfies "doesn't freeze the whole session for players who weren't involved" because it is **per-process local data that is never sent over the network and never read by gameplay code.**

```gdscript
# JuiceManager.gd (new autoload) — illustrative sketch
extends Node

var hitstop_timer: float = 0.0
const HITSTOP_TIME_SCALE: float = 0.06   # how "frozen" cosmetic systems feel, NOT Engine.time_scale

func hitstop(duration: float) -> void:
    hitstop_timer = max(hitstop_timer, duration)   # don't shorten an already-longer hitstop

## Cosmetic systems call this INSTEAD OF get_process_delta_time() for their own tick.
## Never call this from _physics_process gameplay code (movement, damage, cooldowns).
func cosmetic_delta(delta: float) -> float:
    if hitstop_timer > 0.0:
        hitstop_timer -= delta
        return delta * HITSTOP_TIME_SCALE
    return delta
```
Camera shake decay, a sprite-flash `Tween`'s manual step, and a particle timestep all call `JuiceManager.cosmetic_delta(delta)` instead of using `delta` directly. Movement, AI, ability cooldowns, and all RPC-triggered state changes keep using real `delta` untouched.

---

## Data Flow — Integration Points Per Feature

| Feature (from PROJECT.md) | Pattern | Hook point | New RPC? |
|---|---|---|---|
| Floating damage numbers on enemy hit | A | `Enemy._process` hp-diff (existing `Sfx.hit()` site) | No |
| Hit-flash on enemy | A | Same hp-diff site | No |
| Screen shake + hit-flash + HP-bar-flash on player taking damage | A | `Player._process` health-diff (existing `_last_health_seen` site); **shake only applied if `is_multiplayer_authority()`** — you only shake your own camera, and only the player who was actually hit shakes at all | No |
| Hit-stop on enemy kill | C | `Enemy._exit_tree()` (fires on every peer when the spawner-replicated `queue_free()` removes the node — see below) calls `JuiceManager.hitstop(...)` locally | No |
| Death particle burst | A (structural note below) | `Enemy._exit_tree()`, **not** `take_damage()` | No |
| Weapon/element-specific hit VFX (fire scorch, ice shatter, earth crack) | A, but requires a small replication fix first | See "Status-effect visibility gap" below | No (fix is a sync-config addition, not an RPC) |
| XP orb magnetism + travel-to-bar | A (pure local cosmetics) | `XpOrb._process` (new) tweens position toward the nearest already-replicated player position; actual collection RPC unchanged | No |
| Pickup pop/bounce/floating text (weapon unlocks) | A | Existing `weapon_unlocked` RPC handler (`@rpc("authority","call_local")`, already broadcasts) — just add VFX inside it | No — piggybacks on existing broadcast |
| Level-up burst + card pop-in | A | Existing `is_picking_card` diff / `_sync_team_xp` RPC (already `call_local`) | No |
| Evolution stage transform ("closure" moment) | A, camera parts gated | Existing `set_evolution_stage` RPC (already fires on all peers) / `evolution_stage` is already in the ~20 Hz sync set too — double-covered already. Screen-space effects (personal flash/slow-mo) gated to `is_multiplayer_authority()`; particle/model-transform effects run for everyone since the character node itself is visible to all peers already | No |
| Ability juice: dash trail, aura pulse, heal sparkle, drone deploy | A | `dash_invincible`/`shield_active` diffs (Player), `HealDrone._ready()` (already spawner-broadcast to all peers) | No |
| Enemy spawn-in effect | A | `Enemy._ready()` (already runs on every peer via `EnemySpawner`) | No |
| Downed collapse animation | A | `is_downed` diff (already replicated) | No |
| Revive progress ring visible to all | B (widen existing single-target RPC) | `Player.set_revive_progress` — change from `@rpc("any_peer","call_remote")` + `rpc_id(target_id,...)` to `@rpc("any_peer","call_local")` + `target.set_revive_progress.rpc(progress)` (broadcast). **Safe because Player nodes have deterministic cross-peer names** (`Player_%d`), unlike Enemy/Bullet | Modifies existing RPC, no brand-new channel |
| Revive success burst | A | `is_downed` true→false diff (already replicated) | No |
| Big hit juice (SUSPENSION-linked) visible to all, at the hit location | B (new) | New `GameEvents.emit_big_hit.rpc(pos)`, called alongside the existing `emit_hud.rpc("suspension")` in `notify_significant_hit()` | **Yes — one new RPC** (position payload the existing string-only `emit_hud` can't carry) |
| Healing juice visible to all | A | **Already implemented today** (`_spawn_heal_particles` reacting to health-diff) — this milestone just needs to make it juicier (bigger, paired sound), not re-architect it | No |

---

## The Status-Effect Visibility Gap (discovered, not hypothetical)

`Enemy.apply_burn()` / `apply_slow()` set `modulate` directly, and are called **only** from `Bullet.gd`'s host-only-gated `_on_area_entered`. The countdown/clear logic for these tints lives in `Enemy._tick_status_effects()`, called from `_physics_process`, which is **host-only** (`set_physics_process(is_multiplayer_authority())`). Nothing in the current `SceneReplicationConfig` (per the in-file comments, only `current_hp`/`state`-adjacent fields are called out as synced) appears to replicate `modulate` or a status flag. **This strongly suggests the burn/ice tint currently only renders correctly on the host's own screen, not on clients** — a pre-existing gap this milestone's "weapon/element-specific hit VFX" requirement will otherwise silently inherit.

**Fix (small, targeted):** add two booleans (`is_burning`, `is_slowed`) to Enemy's replicated field set, written by the host-only tick as today, but **read** by a new block inside `_process()` (which already runs on all peers) to drive the tint/particle. Gameplay math (the DoT damage tick, the speed multiplier) stays exactly where it is, host-only. This is a one-file, low-risk fix and should happen *before* building the fire/ice/earth hit VFX on top of it, or the new VFX will inherit the same client-invisible bug.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: RPC-targeting a dynamically-spawned `Enemy` or `Bullet` node directly

**What people would do:** Add `@rpc(...) func _show_hit_vfx(...)` directly on `Bullet.gd` or `Enemy.gd` and call it as `self.rpc(...)` or `enemy.rpc(...)` from host.

**Why it's wrong:** Godot's high-level multiplayer API addresses per-node RPCs by the node's **path**, which must match across peers. `Game.gd`'s `_do_spawn_bullet`/`_do_spawn_enemy` are `MultiplayerSpawner.spawn_function` callbacks — per Godot's documented behavior, **the callback runs independently on every peer** with the same `data` dict, not once-and-replicated. This codebase names those nodes with `randi()` (`"Bullet_%d" % (randi() % 99999)`, `"Enemy_%d" % (randi() % 9999)`), and `randi()` is **not** seeded identically across peers — so the resulting node name (and thus path) is very likely **different on every peer**. An RPC call addressed at that per-peer path will fail to resolve on remote peers. This has been harmless so far because nothing currently RPCs to a specific Enemy/Bullet node — everything routes through `Game.gd` (stable `/root/Game` path), `GameEvents` (stable autoload path), or `rpc_id`-targeted `Player` nodes (which ARE named deterministically, `"Player_%d" % data["id"]`, since `data["id"]` — the peer id — is identical on every peer).

**Do this instead:** Route any new juice broadcast through a stable-path node (`Game.gd`, `GameEvents`) carrying the position/id/amount as RPC arguments, exactly like the existing `_show_dash_shockwave` and `emit_hud` patterns already do.

### Anti-Pattern 2: `Engine.time_scale` or `get_tree().paused` for hit-stop

Covered in detail above (Pattern C). Both are global, both interact badly with this project's host-authoritative simulation and its already-established "never pause SceneTree" precedent.

### Anti-Pattern 3: Putting juice logic inside authority-gated gameplay functions

**What people would do:** Add a particle burst call inside `Enemy.take_damage()` (host-only-gated) expecting it to show everywhere, or inside `Bullet._on_area_entered` (also host-only-gated).

**Why it's wrong:** These functions only *execute their body* on the host (`if not is_multiplayer_authority(): return`). Any visual side effect placed there is invisible on every client — this is exactly the bug class described in the status-effect gap above.

**Do this instead:** Put the VISUAL reaction in code that already runs on **every** peer (`_process`, `_ready`, `_exit_tree` for spawner-managed nodes, or an explicit `call_local` RPC), driven by a field that is (or is now) replicated. Keep the *gameplay* mutation host-only as today.

### Anti-Pattern 4: One giant "VFX god function" duplicated per feature

The codebase already shows early signs of this (`_spawn_heal_particles` and `_spawn_driver_particles` in `Player.gd` are ~90% identical). Centralize the CPUParticles2D builder in `scenes/vfx/ImpactBurst.gd` and parametrize (color, count, gravity, lifetime) instead of copy-pasting a fourth/fifth variant for death bursts, level-up bursts, evolution bursts, and pickup pops.

---

## Scaling Considerations (interpreted for a 1–3 player LAN demo, not a web-scale audience)

| Concern | 1 player (solo host testing) | 2–3 players (target) | Notes |
|---|---|---|---|
| Replication-tick granularity for damage numbers | Non-issue | Minor: simultaneous multi-bolt hits (Fire Burst) may under-count distinct numbers within one ~50 ms sync tick | Acceptable trade-off; upgrade to Pattern B only if playtesting shows it looks wrong |
| Particle node churn (CPUParticles2D one-shot, `add_child` + `queue_free` per burst) | Trivial | Could matter during dense boss-phase mob-swarm moments (many simultaneous deaths + hits) at once on GL Compatibility renderer on laptop-class GPUs | Centralized `ImpactBurst` helper makes it trivial to add a simple cap (e.g. skip spawning a burst if >N are already active) without touching every call site |
| Hit-stop stacking | N/A | Multiple near-simultaneous kills each calling `JuiceManager.hitstop(duration)` | Use `max()` not additive stacking (see sketch above) — prevents a wave clear from freezing cosmetics for seconds |
| New RPC traffic | None | Two small new/modified RPCs (`emit_big_hit`, widened `set_revive_progress`) at LAN scale | Negligible — LAN bandwidth is not a constraint for this project (per PROJECT.md constraints) |

### Renderer note

`project.godot` pins `renderer/rendering_method="gl_compatibility"`. The codebase consistently uses `CPUParticles2D`, not `GPUParticles2D`, for every existing burst effect (heal, driver-mode sparkles). **Stay consistent with `CPUParticles2D`** for all new juice particles — it's the established, tested convention on this rendering path and there's no reason introduced by this milestone to deviate.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Enemy.gd` ↔ `JuiceManager` | Direct local call from `_process`/`_exit_tree`/`_ready` | No authority check needed inside `JuiceManager` calls themselves — the caller already only runs cosmetic code that's safe on every peer |
| `Player.gd` ↔ `JuiceManager` | Direct local call from `_process`; screen-affecting calls (shake) additionally gated by `is_multiplayer_authority()` | Only the local authoritative player's `Camera2D` is even `enabled` (existing code: `$Camera2D.enabled = is_multiplayer_authority()`), so shake is naturally scoped already — just don't call `shake()` for a health-diff on a *remote* player's node |
| `GameEvents` ↔ all listeners | `@rpc("authority","call_local","reliable")`, mirrors existing `emit_hud`/`emit_driver_mode` | Extend with `big_hit(pos)`; do not create a parallel signal bus |
| `Game.gd` ↔ `Player.gd` (revive ring) | Widen `set_revive_progress` from `rpc_id` to `.rpc()` broadcast | Safe due to deterministic Player node naming |
| `XpOrb.gd` ↔ `Player.gd` positions | Read-only local access to already-replicated `global_position` of nearby players (via `get_tree().get_nodes_in_group("players")`, same pattern `Enemy._find_nearest_player` already uses) | Purely cosmetic magnetism target selection; does not need to match exactly across peers |

---

## Suggested Build Order

1. **Foundation:** `JuiceManager` autoload (shake, cosmetic_delta/hitstop, spawn_damage_number, flash, burst helper) + `scenes/vfx/` scene stubs. No gameplay-file edits yet — buildable and testable in isolation.
2. **Local-reactive layer (Pattern A), the highest-value/lowest-risk work:** wire `Enemy._process` (damage numbers, hit-flash, death burst via `_exit_tree`), `Player._process` (health-diff shake/flash, `is_downed` collapse, evolution-stage transform reacting to existing RPC), `XpOrb` magnetism + HUD bar decoupling, `HealDrone`/`Enemy._ready` spawn-in effects, existing `weapon_unlocked` handler pickup-pop. Zero new RPCs in this whole phase.
3. **Status-effect replication fix:** add `is_burning`/`is_slowed` to Enemy's synced fields and move the tint/particle reaction into `_process`; only then build fire/ice/earth-specific hit VFX on top.
4. **New/widened broadcasts (Pattern B):** widen `set_revive_progress` to a broadcast; add `GameEvents.emit_big_hit(pos)` for the SUSPENSION-linked big-hit VFX.
5. **Hit-stop wiring (Pattern C):** implement `JuiceManager.hitstop`/`cosmetic_delta`; retrofit camera shake decay, sprite flash, and particle timestep to use it; trigger from kill (local, via `_exit_tree`) and from the big-hit broadcast (step 4). Keep isolated and test explicitly in a real 2–3 machine LAN session, since this is the one area where a mistake (accidentally touching `Engine.time_scale` or `get_tree().paused`) has session-wide consequences instead of local-only consequences.
6. **Evolution stage transform "closure" moment (do last — highest complexity, combines everything above):** particle epic burst + character swap (already broadcast today) + screen flash/slow-mo scoped to `is_multiplayer_authority()` only + sound stinger. Build last because it composes hitstop + shake + particles + sound simultaneously — easiest to get right once all the individual primitives are already validated.
7. **Full sound pass:** attach `Sfx`/`Music` cues to every hook added in steps 2–6. Cross-cutting, so it's fastest to do once all the visual hook points already exist rather than interleaved.

---

## Sources

- Direct codebase reading (HIGH confidence): `scenes/Player.gd`, `scenes/enemies/Enemy.gd`, `scenes/projectiles/Bullet.gd`, `scenes/pickups/XpOrb.gd`, `autoloads/GameEvents.gd`, `autoloads/GameState.gd`, `scenes/Game.gd`, `project.godot`, `.planning/PROJECT.md`
- [How to frame freeze without pausing entire game — Godot Forum](https://forum.godotengine.org/t/how-to-frame-freeze-without-pausing-entire-game/85550) (MEDIUM — community discussion, confirms `Engine.time_scale` freezes everything globally and per-object pause via `get_tree().paused` only affects `_physics_process`)
- [How should I implement hitstop? — Godot Forum](https://forum.godotengine.org/t/how-should-i-implement-hitstop/45146) (MEDIUM — corroborates the same global-vs-local trade-off)
- [Pausing games and process mode — Godot Engine official docs](https://docs.godotengine.org/en/latest/tutorials/scripting/pausing_games.html) (HIGH — official semantics of `SceneTree.paused` and `process_mode`)
- [Screen Shake :: Godot 4 Recipes](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html) and [Bite-sized Godot: Better screen shake — The Shaggy Dev](https://shaggydev.com/2022/02/23/screen-shake-godot/) (MEDIUM — trauma-based, noise-driven Camera2D shake is the standard Godot 4 technique; directly applicable since this project already scopes exactly one enabled `Camera2D` per local authoritative player)
- [Multiplayer in Godot 4.0: Scene Replication — official Godot Engine article](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/) (HIGH — confirms `MultiplayerSpawner.spawn_function` callbacks run independently on every peer given the same `data`, and that spawned-node identity across peers is path/name-based — the basis for the "don't RPC-target Enemy/Bullet nodes directly" anti-pattern)
- [MultiplayerSpawner — Godot 4 class reference](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html) (HIGH — official API semantics for `spawn_function`)

---
*Architecture research for: Juicy Feedback / game-feel polish milestone (Godot 4 host-authoritative co-op roguelike)*
*Researched: 2026-07-13*
