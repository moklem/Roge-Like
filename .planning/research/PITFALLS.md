# Pitfalls Research

**Domain:** Game-feel/juice polish added to an existing Godot 4 host-authoritative multiplayer co-op roguelike (v1.1 Juicy Feedback milestone)
**Researched:** 2026-07-13
**Confidence:** HIGH (grounded in direct reading of this project's `Player.gd`, `Enemy.gd`, `Bullet.gd`, `Sfx.gd`, `GameEvents.gd`, `project.godot`, cross-checked against Godot 4 official docs and community sources)

This file supersedes the prior milestone's `PITFALLS.md` (RPC signature discipline, `peer_connected` gating, authority guards, 20 Hz sync scope, `MultiplayerSpawner` registration, non-pausing card UI, host-authoritative loop/XP state) — those are now established, working project conventions and are assumed solved. This file only covers pitfalls specific to **adding juice to this already-working multiplayer codebase**.

---

## Critical Pitfalls

### Pitfall 1: `Engine.time_scale` hit-stop silently breaks this project's un-synced bullet simulation and is not actually a "shared" effect

**What goes wrong:**
`Engine.time_scale` is a per-process engine singleton property. Each peer (host or client) is a **separate OS process** on a **separate laptop** — setting it on one machine has zero effect on any other machine. Naively calling `Engine.time_scale = 0.05` on a kill:

- On a **client**: freezes/slows that peer's own `_physics_process` delta globally — their own WASD input responsiveness, `WeaponManager.tick(delta)` auto-fire timers, ability cooldowns (`_ability_cooldown -= delta`), dash i-frame timers, and — critically — their own **locally-simulated bullets** (`Bullet.gd` explicitly has *no* `MultiplayerSynchronizer`; per its own comment, "clients simulate movement locally from baked direction," trusting that every peer's wall-clock delta accumulates identically). If that one client scales its local delta down for the hit-stop window, its bullets travel a shorter real-world distance than the "same" bullet instance on every other peer for that same wall-clock interval. There is no synchronizer to correct this afterward — the desync in bullet position is permanent until that bullet despawns. Meanwhile the enemy's replicated `current_hp`/position still arrive at their normal real-time cadence (replication interval is wall-clock based, not `time_scale`-scaled), so the client also perceives the enemy animation timer (`_move_timer`) freeze while the position itself keeps snapping forward — a moonwalk-style animation/position mismatch.
- On the **host**: freezes the host's own authoritative `Enemy._physics_process` and `NavigationAgent2D` pathing for every enemy globally (not just the one that died), meaning ALL enemies visibly stutter for ALL peers (since host is authoritative) — but only the host's own local player input/UI/weapon timers experience the "impact" freeze personally; other clients' own inputs/UI are completely unaffected because `Engine.time_scale` never propagates over ENet. The "shared moment" ends up wildly asymmetric between host and clients.
- Either way, **nothing about `Engine.time_scale` is networked**, so any attempt to make hit-stop feel like a shared team moment (as the milestone goal implies for "big hits") by touching this property is fundamentally the wrong tool — it can only ever be a same-process side effect, never a synchronized broadcast.

**Why it happens:**
Single-player Godot tutorials for hit-stop/freeze-frame almost universally reach for `Engine.time_scale = X` because it is the simplest one-line "make everything feel punchy" trick, and it works fine in a single process with no networked simulation depending on wall-clock-consistent deltas.

**How to avoid:**
Never call `Engine.time_scale =` anywhere in this project. Implement hit-stop as a **local-only cosmetic effect**, decided once in a foundational Juice utility (e.g. an autoload or shared helper) that every effect reuses:
- Gate hit-stop behind a small boolean/counter driven by real frame counts (`await get_tree().process_frame` loops) or by an unscaled timer, and have it pause **only specific rendering elements** — e.g. `AnimatedSprite2D.speed_scale = 0` on the killed enemy's death sprite for a few frames, and a brief camera micro-freeze (skip `Camera2D` repositioning for N frames) — never physics, movement, ability timers, or bullet simulation.
- Since each peer already has its own local-only `Camera2D` (only the local authority player's camera is enabled — established pattern in `Player.gd _ready()`), hit-stop is naturally a **per-peer local reaction**, not a networked state. If a rare "everyone should feel this" moment is wanted (e.g. evolution transform, boss kill), broadcast a lightweight RPC using the existing `GameEvents` `"authority","call_local"` pattern so every peer *independently* triggers its own local cosmetic freeze — do not try to make one machine's freeze "reach" the others via engine state.
- Keep the duration extremely short (tens of ms, e.g. 50–100ms) for routine kills; reserve anything longer (a few hundred ms, "slow-mo" feel) exclusively for rare milestone moments (evolution transform), never for per-kill hit-stop given this game's Vampire-Survivors-style kill rate.

**Warning signs:**
- Any new code containing the literal string `Engine.time_scale`.
- Player reports of "my dash felt weird" / "bullets look like they teleport" after a kill.
- Bullet trajectories visibly differing between host and client screens after a hit-stop-triggering kill.
- Testing only ever done solo (1 instance) — this bug is invisible until tested with 2+ real peers.

**Phase to address:**
Foundational/Core Juice plan (before Combat Feedback plan). Hit-stop scoping (local-cosmetic-only, no `Engine.time_scale`, no SceneTree pause) must be decided and implemented as a shared helper **before** any weapon/kill/evolution effect uses it, or multiple ad hoc implementations will diverge.

---

### Pitfall 2: `GPUParticles2D` will silently fail to render at all under this project's configured renderer

**What goes wrong:**
This project's `project.godot` explicitly sets:
```
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```
The Compatibility (GL Compatibility / OpenGL ES 3.0) renderer in Godot 4 **does not support compute shaders**, which `GPUParticles2D` requires. When a `GPUParticles2D` node is used under this renderer, particles **silently fail to emit — no error, no warning, just nothing on screen.** This is independently confirmed by multiple sources (Godot community bug reports and guides) and matches this project's own already-established convention: every existing particle effect in the codebase (`Player._spawn_heal_particles`, `Player._spawn_driver_particles`) already deliberately uses `CPUParticles2D`, never `GPUParticles2D`. That is not an accident — it is the only particle node that reliably renders under `gl_compatibility` and works uniformly across the demo's mixed laptop hardware (integrated/discrete GPUs from different vendors on 3 separate machines).

**Why it happens:**
`GPUParticles2D` is the "modern"/first-suggested option in most tutorials and the Godot editor's particle-node autocomplete; developers reaching for the flashier evolution-transform or death-burst VFX may not realize the project already made (and depends on) this renderer choice.

**How to avoid:**
Use `CPUParticles2D` exclusively for every new juice particle effect (death bursts, evolution transform particles, pickup pop effects, weapon/element hit VFX), matching the existing convention. Cap `amount` per burst modestly (existing bursts use 14–20, `one_shot=true`, `explosiveness=0.9`) — this is CPU-simulated so cost scales with total concurrent particle count across all active emitters, not per-node overhead.

**Warning signs:**
- A new effect "looks fine in the editor preview" but is invisible when the exported/packaged build runs (editor may use a different rendering path than the exported project depending on settings — always test in the actual running game, not just the editor viewport).
- Any use of `GPUParticles2D`, `GPUParticles2D.process_material`, or `ParticleProcessMaterial` in new juice code — flag immediately in review.

**Phase to address:**
Foundational/Core Juice plan — state the "CPUParticles2D only, never GPUParticles2D" rule explicitly once so every subsequent effect (combat, collection, progression, ability, enemy, downed/revive) inherits it without rediscovering the failure.

---

### Pitfall 3: Reflexively adding a new RPC per hit floods the network; but relying on synced-state-diff for effects tied to despawning nodes silently misses them

**What goes wrong:**
This codebase already has an established, battle-tested pattern for reacting to combat state changes **without any new RPC**: both `Enemy._process` (`if current_hp < _last_hp_seen: Sfx.hit()`) and `Player._process` (`if health > _last_health_seen: _spawn_heal_particles()`) react locally, on every peer, to values that are *already* replicated via `MultiplayerSynchronizer` at 20 Hz. This is free — no extra network traffic. The temptation when adding many new juice effects (floating damage numbers, hit-flash, hit particles) is to instead fire a dedicated RPC per hit "to be safe" — but at this game's expected hit rate (up to 3 players × up to 6 independently-timed weapons, Fire Burst auto-fire, swarm waves) that could mean dozens of additional RPC calls per second, adding needless ENet channel pressure and per-call overhead for effects that could have been driven by data already in flight.
The opposite mistake also exists: **enemy death is not diff-able state** — `Enemy.take_damage()` calls `queue_free()` immediately once `current_hp <= 0`, and `MultiplayerSpawner` propagates that despawn to every client. There is no "current_hp went from small to 0 and I can still read it next frame" moment to react to locally on a client, because the node may already be gone by the time the replicated value or the despawn message is processed — this is a race, not a guarantee. An effect that tries to piggyback on the existing `_last_hp_seen` watch pattern for a **death burst** will be flaky: sometimes it fires, sometimes the node is already freed first.

**Why it happens:**
Developers extending the codebase either don't notice the existing free diff-watch pattern (and default to "just add an RPC, it's simpler") or over-apply it to death, which is fundamentally different from damage (node persists vs. node about to disappear).

**How to avoid:**
Decide, per effect, explicitly:
- **Damage numbers, hit-flash, hit particles, DoT tint changes** → reuse the existing local diff-watch pattern (`_last_hp_seen`/`_last_health_seen`-style), zero new RPC traffic, exactly like the existing `Sfx.hit()` call.
- **Enemy death burst, evolution transform, downed/revive juice** → these are despawn-adjacent or state-transition moments with no reliable "watch it change" window; broadcast explicitly via RPC, following one of the two patterns already established in this codebase:
  - `GameEvents` `@rpc("authority", "call_local", "reliable")` broadcast pattern (for guaranteed, host-decided one-off events), or
  - the `Player._show_dash_shockwave` `@rpc("any_peer", "call_local", "unreliable_ordered")` pattern (for pure-cosmetic, position-based, no-state-mutation visual effects that can tolerate an occasional drop).
  Trigger the death-burst RPC call **inside `Enemy.take_damage()` before `queue_free()`**, passing `global_position` explicitly (the node itself will be gone by the time clients process the despawn), so the burst is spawned as an independent node rather than depending on the dying enemy still existing.

**Warning signs:**
- A new `@rpc` function added for something that already has a replicated property backing it (redundant network traffic).
- A particle/label spawn function that reads `self.global_position` or `self.something` from *inside* the dying enemy's own script *after* `current_hp <= 0` is set but *before* confirming the burst was actually requested pre-`queue_free()` — check ordering carefully.
- Intermittent ("works sometimes") death VFX during playtesting, especially worse on clients than on host, or worse under higher ping/LAN congestion.

**Phase to address:**
Foundational/Core Juice plan should define this rule as a table ("which trigger mechanism for which effect category"); Enemy Feedback plan (death burst, spawn-in effect) is the first consumer and must implement the death-burst RPC-before-`queue_free()` pattern correctly.

---

### Pitfall 4: Parenting a transient juice node to the thing that triggered it gets it destroyed mid-animation

**What goes wrong:**
`Enemy.take_damage()` calls `queue_free()` **immediately** when `current_hp <= 0`. In Godot, `queue_free()` on a parent also frees all its children on the same deferred call. Any juice effect (particle burst, floating damage number, hit-flash overlay) added as a **child** of the Enemy node "for convenience" (so it inherits position automatically) will be destroyed before its animation/particle lifetime completes — it will not be visible at all, or will cut off after a single frame. The same risk applies to any effect parented to a `CardOverlay`, a downed player's revive-ring, or any other node whose owner's lifecycle is shorter than the effect's intended playtime.
The existing codebase already avoids this correctly in its two established VFX patterns: `_spawn_heal_particles`/`_spawn_driver_particles` add the `CPUParticles2D` as a child of the **Player** (which persists for the whole match, unlike an enemy), and `_show_dash_shockwave` explicitly adds the ring to **`game`** (the persistent `Game` node), not to the player or any transient object, using a captured `global_position` rather than relying on being a child of the moving/dying source.

**Why it happens:**
Parenting an effect to its trigger source is the path of least resistance (auto-inherits position/rotation) and works fine for effects whose source node lives at least as long as the effect (e.g. a heal sparkle on a living player) — the bug only appears for effects tied to something that's about to be destroyed (enemy death, bullet impact, orb pickup/consumption).

**How to avoid:**
For any effect triggered by something that dies/despawns/is consumed in the same call (enemy death, bullet-hits-wall/enemy despawn, XP-orb-reaches-bar consumption, card-overlay dismissal): capture `global_position` first, then `add_child()` the effect onto a **persistent container** — either the `Game` node (existing precedent) or a small dedicated `FxLayer`/`Node2D` added once under `Game.tscn` for exactly this purpose. Never parent transient VFX to the node that's about to free itself.

**Warning signs:**
- Death bursts / impact VFX that "sometimes don't show up" or flash for a single frame instead of playing their full animation.
- Effects that work fine in isolated testing (killing one enemy slowly) but disappear during swarm clears (many simultaneous deaths, higher chance of hitting the race).

**Phase to address:**
Foundational/Core Juice plan — establish the `FxLayer` container and the "capture position, parent to FxLayer, never parent to the trigger source" rule before Enemy Feedback / Combat Feedback plans build on it.

---

### Pitfall 5: Damage numbers, screen shake, and shared sound pool all break down under Vampire-Survivors-style simultaneous hit volume

**What goes wrong:**
This game's core loop (up to 3 players, up to 6 independently-timed weapons each, Fire Burst auto-fire, swarm waves that intentionally scale up per loop) is explicitly Vampire-Survivors-like — meaning many enemies can be hit or killed within the same second, especially late in a loop. Three specific juice systems break down under this volume if built naively:

1. **Floating damage numbers**: spawning one `Label`/`RichTextLabel` + `Tween` per individual hit (per bullet, per tick) during a swarm clear can produce dozens of overlapping number nodes per second, each with its own Tween. This both costs real frame time (node instancing + tween allocation) and — more importantly for the stated "discernability" design goal — becomes unreadable: numbers stack directly on top of each other and the screen becomes visual noise exactly when players most need clarity.
2. **Screen shake**: with 3 players independently dealing damage across a shared enemy swarm, shaking the camera by a fixed amount on every hit produces near-continuous high-frequency shake with no rest during exactly the busiest, most dangerous moments — impairing the ability to read the battlefield (the opposite of the stated goal) and risking motion discomfort. Since this project is presented **both live and projected to a passive audience** (per `PROJECT.md` Context), a shaking projected image is worse for spectators than for the player who has control input to counteract the vestibular mismatch — this project has a stricter bar for shake restraint than a typical single-player action game.
3. **Shared sound pool starvation**: `Sfx.gd` uses a single shared round-robin pool of 12 `AudioStreamPlayer`s for the *entire scene* (not per-weapon, not per-player). Under heavy multi-weapon fire from 3 players simultaneously, rapid "shoot"/"hit" calls can exhaust and steal voices from each other within well under a second, causing audible clipping/interruption or an indistinguishable "wall of noise." Adding many new one-shot juice stingers (kill fanfare, level-up burst, evolution stinger) into the *same* shared pool risks them being stolen mid-playback by routine hit ticks during a busy moment — exactly when a "big hit" or "kill" sound most needs to be heard clearly.

**Why it happens:**
Juice patterns that look and feel great in isolated testing (killing one enemy at a time) are usually built and tuned against that light-load scenario, and the breakdown is invisible until playtested under the game's actual designed difficulty curve (later loops, swarm waves) — which may not happen until integration/playtesting late in the milestone.

**How to avoid:**
- **Damage numbers**: pool a fixed, capped number of number-label nodes (reuse instead of continuously instancing); aggregate rapid repeat hits on the same target within a short window (e.g. ~100ms) into a single summed number instead of one per tick; add small random position jitter so simultaneous numbers don't perfectly overlap.
- **Screen shake**: use an additive "trauma" accumulator (clamped 0–1, decaying every frame, shake magnitude derived from `trauma^2` or similar) rather than an independent full-strength shake Tween per hit — this is the standard technique (Squirrel Eiserloh's GDC talk; implemented in the Godot community's "kidscancode" screen-shake recipe). Tier magnitude by event significance (routine hit ≈ none/tiny, kill/big-hit/boss ≈ noticeable) rather than uniform-per-hit. Scope shake to each peer's own local `Camera2D` and trigger it only from events relevant to that peer (their own damage dealt/taken), not from every hit anywhere on screen dealt by teammates, to avoid amplifying shake 3x in co-op swarms.
- **Sound**: give rare "must-hear" stingers (kill fanfare, level-up, evolution transform, downed/revive) either a small **reserved/dedicated voice pool** separate from the routine hit/shoot pool, or a priority scheme so they cannot be stolen by routine hits; rate-limit/gate repeated identical stingers (e.g. don't re-trigger a full kill fanfare for every kill within a fast swarm clear — cooldown-gate or only play for every Nth kill / the first kill of a burst) rather than 1:1 firing.

**Warning signs:**
- Damage numbers become unreadable, or FPS drops, specifically during swarm waves or late-loop testing (not visible in early/light testing).
- Screen feels shaky/uncomfortable specifically during multi-enemy or multi-player combat, especially noticeable when watching a recording/projection rather than playing.
- Audible clicking, sudden sound cutoffs, or "kill fanfare" never being heard during busy fights, reported only once playtesting includes 3 real players firing simultaneously.

**Phase to address:**
Combat Feedback plan (damage numbers, shake) and the Sound Design pass — both should explicitly design for "many simultaneous hits" from the start (cap + aggregate + prioritize), not retrofit it after a swarm-testing bug report. Foundational plan should provide the shared trauma-accumulator and number-pool utilities so every subsequent plan reuses the same restrained implementation rather than each plan inventing its own uncapped version.

---

### Pitfall 6: Orphaned Tween/particle/label nodes accumulate over a continuous 15-minute loop

**What goes wrong:**
The milestone adds many new transient VFX types (damage numbers, particle bursts, hit-flash overlays, progress rings) on top of the existing safe patterns. The existing codebase's safe cleanup idioms are: `CPUParticles2D` one-shot bursts free themselves via `p.finished.connect(p.queue_free)`, and Tween-driven effects (`_show_dash_shockwave`) explicitly end with `tween.tween_callback(ring.queue_free)`. Every *new* effect must replicate one of these, and it is easy to forget — a developer copying only the "spawn + tween the value" half of the pattern and omitting the terminal `queue_free()` call leaves the node in the tree permanently. At this game's expected hit/spawn rate (multiple players × multiple weapons × continuous swarm spawning over a full 15-minute loop, with no natural loop-reset relief mid-loop), even a small per-effect leak rate compounds into real, measurable node-count and memory growth **before the loop itself resets** — degrading frame rate progressively over the same session rather than failing immediately, which makes it easy to miss in short manual playtests and only surface near the end of a full 15-minute run.
A second, more subtle version of this bug: `CPUParticles2D.finished` is documented to fire once a one-shot emitter has finished emitting **and** all its particles have died — but this depends on `emitting = true` actually being set and observed correctly; a defensive backstop is cheap insurance and this codebase doesn't currently have one for any of its particle effects.

**Why it happens:**
Cleanup callbacks are an easy detail to omit under time pressure when there are many new effect types to build in one milestone, and the bug is invisible in quick testing (a leak of a few nodes doesn't show up until a real, sustained 15-minute session accumulates hundreds/thousands of them).

**How to avoid:**
- Centralize spawn+cleanup for each juice category into a small number of shared helper functions (a "Juice"/"Fx" utility) rather than each of the ~10 new effect types (damage numbers, level-up burst, evolution transform, dash trail, aura pulse, heal sparkle, drone deploy, enemy spawn-in, death burst, downed/revive ring) re-implementing spawn/cleanup ad hoc — one correct implementation reused everywhere beats ten near-identical ones with a copy-paste risk.
- Always add a **defensive backstop** alongside the "proper" signal-based cleanup: e.g. `get_tree().create_timer(lifetime + 0.5).timeout.connect(node.queue_free)` in addition to (not instead of) the `finished`/`tween_callback` path, guaranteeing cleanup even if the primary signal doesn't fire as expected — `queue_free()` on an already-freed node is a documented no-op/safe call in Godot, so a redundant backstop is harmless.
- For very high-frequency effects specifically (damage numbers, hit-flash — the ones spawned dozens of times per second under swarm load), prefer a small object **pool** of reusable nodes over continuous instantiate/free cycles, both to bound worst-case node count and to reduce allocation churn over a long session.
- Test leak-proneness with a genuinely long session (approaching the real 15-minute loop duration), watching node count (`get_tree().get_node_count()` or the remote debugger's node monitor) over time, not just a 1–2 minute smoke test — and test this **separately on host and on client roles**, since each peer runs its own independent local VFX node lifecycle (these are never part of `MultiplayerSpawner` tracking), so a leak on one role does not guarantee the same leak exists (or is absent) on the other.

**Warning signs:**
- Frame rate that degrades progressively over a single long session without any single reproducible spike — check node count growth over time, not just FPS.
- Any new effect-spawning function that adds a child node but has no matching `queue_free()` path traceable in the same function or a connected signal.
- Leak reproduces on host but not client (or vice versa) during testing — confirms per-peer-local VFX lifecycle bugs, not a shared/network issue.

**Phase to address:**
Foundational/Core Juice plan should build the shared pooling/backstop-cleanup helper before any of the ~10 individual effect plans (Combat/Collection/Progression/Ability/Enemy/Downed-Revive Feedback) start spawning nodes; a final integration/soak-test pass near the end of the milestone should specifically run a full ~15-minute loop while watching node count.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Reusing the shared 12-voice `Sfx` pool for all new juice stingers instead of adding priority/reserved voices | Fast to wire up, no new code | Rare "must-hear" stingers (kill fanfare, evolution) get stolen by routine hit sounds during busy fights | Never for milestone-goal moments (evolution, downed/revive); acceptable for genuinely low-priority ambient ticks only |
| Spawning damage numbers/particles as plain uncapped instantiate-then-free instead of pooling | Simpler code, faster to ship first version | Node count and allocation churn scale linearly with kill rate; degrades over a full 15-min session under swarm load | Acceptable for early prototyping/first pass; must be pooled before final integration if swarm testing shows frame drops |
| Parenting a juice effect to its trigger node for convenience (auto-inherits position) | Less boilerplate, no manual position capture | Effect is destroyed mid-animation if the trigger node (enemy, bullet, orb) despawns in the same frame | Only acceptable when the trigger node's lifetime is guaranteed to outlast the effect (e.g. a persistent Player node) |
| Triggering hit-stop via `Engine.time_scale` for a "quick first pass" to see how it feels solo | Immediate, visible payoff in single-instance testing | Breaks bullet-position trust across peers and produces asymmetric host/client experience; must be entirely re-architected once multiplayer-tested | Never — even a "temporary" implementation risks becoming load-bearing once it "feels good" solo; build the local-cosmetic version from the start |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|--------------|-----------------|-------------------|
| `MultiplayerSynchronizer` (existing 20 Hz sync of position/health/is_downed/xp/level/stage/element) | Adding a brand-new RPC for every juice reaction to state that's already synced (damage numbers, hit-flash, DoT tint) | Reuse the existing local diff-watch pattern (`_last_hp_seen`/`_last_health_seen`-style) already established in `Enemy.gd`/`Player.gd` — zero extra network cost |
| `MultiplayerSpawner` despawn (enemy `queue_free()` on death) | Assuming the dying node will still exist on the next frame/tick to react to (it may already be gone via despawn propagation) | Trigger despawn-adjacent effects (death burst, kill sound) via an explicit RPC *before* `queue_free()`, carrying `global_position`, and spawn the effect on a persistent container, not the dying node |
| `GameEvents` RPC broadcast pattern (`"authority","call_local","reliable"`) | Inventing a third ad hoc broadcast pattern for new juice events instead of reusing the two already established (`GameEvents` reliable broadcast, or `_show_dash_shockwave`-style `"any_peer","call_local","unreliable_ordered"` cosmetic broadcast) | Pick one of the two existing patterns per effect based on whether it's host-decided/guaranteed (reliable) or pure cosmetic/position-based (unreliable) — don't add a third variant |
| Per-peer local `Camera2D` (enabled only for the local authority player) | Applying screen shake/hit-stop as if it were shared/networked state | Treat all camera-affecting juice as inherently local-only per peer; broadcast the *trigger* via RPC if it must be felt by everyone, but always apply the actual shake/freeze locally on each peer's own camera |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| `GPUParticles2D` used instead of `CPUParticles2D` | Particles invisible in the exported/running build under this project's `gl_compatibility` renderer (silent failure, no error) | Use `CPUParticles2D` exclusively, matching existing codebase convention | Immediately — not a scale issue, a renderer-compatibility issue confirmed by this project's own `project.godot` config |
| Uncapped damage-number/particle instancing per hit | Frame drops and screen clutter specifically during swarm waves / late loops, not visible in light 1v1 testing | Pool nodes, aggregate rapid repeat hits into one number, cap concurrent active count | Breaks once hit rate exceeds roughly a handful per second — i.e. exactly the swarm-wave/late-loop scenario this game is designed to escalate toward |
| Per-hit RPC broadcast for cosmetic reactions | Added network chatter, minor latency/jitter on LAN, worse if tested with weaker Wi-Fi instead of wired LAN | Prefer local diff-watch on already-synced state for anything that isn't despawn-adjacent | Becomes noticeable as weapon count/fire rate increases across all 3 players simultaneously |
| Shared 12-voice `Sfx` pool used for every new stinger | Audible cutoffs/stolen voices, "wall of noise" during heavy multi-weapon fire from 3 players | Reserve/prioritize voices for rare must-hear stingers; rate-limit routine repeats | Breaks once total concurrent sound-triggering events across all 3 players exceeds the 12-voice pool within a short window — plausible during full 3-player swarm clears with maxed weapon loadouts |
| Testing juice only with 1 local instance | Everything looks/feels fine solo; multiplayer-specific bugs (time_scale asymmetry, RPC race on despawn, per-peer leak differences) are invisible | Test with at least 2 real processes (host + client) throughout the milestone, not just at the end | Breaks the moment a second peer is involved — which is this game's actual primary use case |

## Security Mistakes

This is a friendly LAN demo (not adversarial), so classic security concerns are low-relevance, but one host-authority-adjacent note applies:

| Mistake | Risk | Prevention |
|---------|------|------------|
| Accepting juice-trigger RPCs from clients without any rate/sanity limit (e.g. a client-originated "play evolution stinger" or "spawn burst" RPC) | A buggy (not necessarily malicious) client could spam a juice RPC in a tight loop, degrading performance for the whole team on a LAN demo | Keep juice-triggering authority host-side wherever the underlying game event is already host-authoritative (enemy death, damage, evolution) — clients should only ever be the *recipients* of juice RPCs, never the originators, mirroring the existing damage/health authority model |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|--------------|-------------------|
| Screen shake and damage numbers scaled the same regardless of hit volume | Screen becomes unreadable exactly during the busiest, most dangerous swarm moments — the opposite of the "discernability" goal | Tier/aggregate juice intensity inversely with event frequency (routine hits get subtler feedback than rare big hits) |
| Juice effects designed only for player-side viewing | Effects tuned to feel good with active control input (which counteracts motion discomfort) may be uncomfortable for the passive projected audience mentioned in this project's Context | Keep shake amplitude conservative and test by watching a recording/projection, not only by playing |
| Per-player level-up card pick juice affecting the whole screen/team | Breaks the already-established "per-player level-up doesn't pause the game for other players" design decision | Scope level-up burst/card-pop-in juice to the picking player's own screen only; no team-wide shake/slowdown/sound-flood from one player's pick |
| Identical, un-varied sound/particle for every hit | Becomes a monotonous "wall of noise" during sustained fire, especially with 3 players' weapons overlapping | Reuse the existing pitch-variance pattern in `Sfx.gd` (`randf_range` on `pitch_scale`) for all new stingers, and vary particle color/size/timing slightly per instance |

## "Looks Done But Isn't" Checklist

- [ ] **Hit-stop:** Often "implemented" via `Engine.time_scale` because it feels great solo — verify it has never appeared as `Engine.time_scale =` anywhere, and that it was tested with 2+ real peers (host + client) for bullet-position and animation desync.
- [ ] **Particle effects:** Often built and previewed only in the editor viewport — verify every new emitter is `CPUParticles2D` (never `GPUParticles2D`) and actually visible in an exported/running build given this project's `gl_compatibility` renderer.
- [ ] **Death burst / despawn-adjacent VFX:** Often "working" in slow 1-enemy testing but flaky under swarm clears — verify the effect is triggered via RPC *before* `queue_free()` with a captured `global_position`, parented to a persistent container, not the dying enemy.
- [ ] **Damage numbers / screen shake:** Often tuned and approved during light 1v1 testing — verify behavior specifically during a late-loop swarm wave with all 3 players firing simultaneously (aggregation/caps must be visibly active, not just "usually fine").
- [ ] **New sound stingers:** Often added and confirmed audible in isolated testing — verify they are still audible (not stolen by the shared pool) during simultaneous heavy multi-weapon fire from all 3 players.
- [ ] **Cleanup for every new effect type:** Often verified only by "it disappeared eventually" in a short test — verify a real ~15-minute continuous-loop soak test shows stable (non-growing) node count, on both host and client roles independently.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| `Engine.time_scale` hit-stop shipped and later found to desync bullets | MEDIUM | Replace with local-cosmetic freeze (animation `speed_scale`/camera micro-freeze); re-test bullet trajectories across host/client after the swap |
| `GPUParticles2D` effect found invisible in exported build | LOW | Swap node type to `CPUParticles2D` with equivalent `ParticleProcessMaterial`-derived properties; re-test in an actual exported/packaged run, not just the editor |
| Death-burst VFX found flaky under swarm testing (race with despawn) | MEDIUM | Move the trigger into `Enemy.take_damage()` before `queue_free()`, convert to an explicit RPC carrying `global_position`, reparent the spawned effect to the persistent `FxLayer`/`Game` node |
| Node/memory leak discovered late via a long soak test | MEDIUM–HIGH depending on how many effect types are affected | Audit every new spawn function for a matching cleanup path; retrofit the shared backstop-timer pattern; re-run the soak test to confirm stabilization |
| Screen shake/damage numbers found overwhelming during swarm playtesting | LOW–MEDIUM | Introduce the trauma-accumulator and number-aggregation/pooling utilities retroactively; tune magnitude tiers by event significance |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| `Engine.time_scale` hit-stop desync | Foundational/Core Juice plan (before any effect using hit-stop) | Grep codebase for `Engine.time_scale`; playtest a kill with 2+ real peers and compare bullet positions/animation on both screens |
| `GPUParticles2D` silent failure under `gl_compatibility` | Foundational/Core Juice plan (state the CPUParticles2D-only rule) | Grep for `GPUParticles2D`; visually confirm every new particle effect renders in an actual running (not just editor) build |
| RPC-per-hit flooding vs. despawn race on state-diff | Foundational/Core Juice plan (define the trigger-mechanism table); Enemy Feedback plan (first consumer, death burst) | Network traffic sanity check during heavy fire; repeated swarm-clear testing shows death VFX firing reliably every time, on host and client |
| Transient VFX parented to trigger source | Foundational/Core Juice plan (establish `FxLayer` container) | Code review: every new effect captures `global_position` and parents to `FxLayer`/`Game`, never to the enemy/bullet/orb triggering it |
| Damage number / shake / sound overload under swarm volume | Combat Feedback plan + Sound Design pass | Dedicated swarm-load playtest (3 players, late-loop difficulty) checking readability, comfort, and audible stingers |
| Orphaned juice nodes over a 15-minute loop | Foundational/Core Juice plan (shared pooling/backstop helper); final integration/soak-test pass | Full ~15-minute loop soak test watching node count on both host and client independently |

## Sources

- Direct project inspection: `scenes/Player.gd`, `scenes/enemies/Enemy.gd`, `scenes/projectiles/Bullet.gd`, `autoloads/Sfx.gd`, `autoloads/GameEvents.gd`, `project.godot` (rendering section) — this project's own established conventions are the primary evidence base (HIGH confidence, directly verified).
- [GPUParticles2D — Godot Engine (stable) documentation](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html) — HIGH confidence, official docs.
- [No GPU activity when using compatibility renderer · Issue #102634 · godotengine/godot](https://github.com/godotengine/godot/issues/102634) — MEDIUM-HIGH confidence, official repo issue tracker, corroborates Compatibility renderer + compute shader limitation.
- [GPU Particles 2D/3D in compatibility rendering sometimes don't emit on 4.2 · Issue #84072 · godotengine/godot](https://github.com/godotengine/godot/issues/84072) — MEDIUM confidence, corroborating official issue.
- [Fix: Godot Particles Not Showing in Exported Build (Bugnet)](https://bugnet.io/blog/fix-godot-particles-not-showing-in-exported-build) — MEDIUM confidence, community source, consistent with official issues above.
- [How should I implement hitstop? - Godot Forum](https://forum.godotengine.org/t/how-should-i-implement-hitstop/45146) — MEDIUM confidence (community discussion, confirms `Engine.time_scale = 0` and SceneTree pause are both widely recognized as problematic, though the thread itself doesn't resolve to one canonical answer).
- [Timer / Engine.time_scale? - Godot Forum](https://forum.godotengine.org/t/timer-engine-time-scale/11222) and [Engine.time_scale doesn't work with timers? - Godot Forum](https://forum.godotengine.org/t/engine-time-scale-doesnt-work-with-timers/74824) — LOW-MEDIUM confidence, community reports corroborating that `Engine.time_scale` interacting with timers/physics is a known source of confusion and side effects.
- [Screen Shake :: Godot 4 Recipes (kidscancode)](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html) — MEDIUM-HIGH confidence, well-known community reference implementing the trauma-based shake technique (originating from Squirrel Eiserloh's GDC talk "Juicing your Cameras With Math").
- [Bite-sized Godot: Better screen shake - The Shaggy Dev](https://shaggydev.com/2022/02/23/screen-shake-godot/) — MEDIUM confidence, corroborates the trauma-accumulator pattern with a second independent source.
- General game-feel/juice design theory (Vlambeer's "Juice it or lose it" GDC talk; Steve Swink's *Game Feel*) — HIGH confidence as foundational, widely-cited design theory already referenced by this milestone's own stated goals (discernability + integration); not independently re-verified via a fresh source this session but consistent with the project's `PROJECT.md` framing.

---
*Pitfalls research for: Adding game-feel juice to an existing Godot 4 host-authoritative multiplayer co-op roguelike*
*Researched: 2026-07-13*
