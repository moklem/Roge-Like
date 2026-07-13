# Project Research Summary

**Project:** Rouge-Like — v1.1 "Juicy Feedback" milestone
**Domain:** Game-feel/juice polish layer for an existing Godot 4.6 host-authoritative LAN co-op roguelike (Vampire-Survivors-style bullet-heaven, GL Compatibility renderer)
**Researched:** 2026-07-13
**Confidence:** HIGH

## Executive Summary

This milestone adds screen shake, hit-stop, floating damage numbers, particle bursts, pickup/XP-orb magnetism, evolution transform VFX, ability juice, downed/revive juice, and full sound-cue pairing to a codebase whose core multiplayer loop (host-authoritative ENet, MultiplayerSynchronizer/MultiplayerSpawner, roles/elements) is already built and validated. Nothing here re-litigates the core stack — this is purely an additive presentation layer, and the research overwhelmingly points to built-in Godot 4.6 APIs (Tween, CPUParticles2D, Camera2D, AnimationPlayer, Label/RichTextLabel, AudioStreamPlayer) plus a handful of new hand-rolled scripts (autoloads/Juice.gd or JuiceManager.gd, scenes/fx/), not new packages or addons.

The single most important architectural discovery is that this codebase already contains a proven, working pattern for "juice visible to every player with zero new networking": several scripts (Enemy._process, Player._process) diff already-replicated state (current_hp, health, is_downed, evolution_stage) frame-to-frame and fire local cosmetic reactions independently on every peer. Most of this milestone's "team-visible" requirements (healing, downed collapse, revive, evolution transform trigger) are solvable by extending this exact diff-watch idiom — no new RPCs required. New RPCs are needed only where a value isn't already replicated with the needed precision (a world-space "big hit" position) or where despawn timing makes diffing unreliable (enemy death burst, which must fire from inside take_damage() before queue_free(), carrying global_position, parented to a persistent container — never to the dying node).

The two risks that dominate every research file and must be decided once, up front, before any individual effect is built: (1) hit-stop must never use Engine.time_scale or SceneTree.paused — both are process-global constructs that either freeze the host's authoritative simulation for every connected client, or desync a client's local bullet/animation simulation from replicated truth (this project's Bullet.gd has no synchronizer and trusts identical wall-clock deltas across peers) — the correct implementation is a local, per-peer "cosmetic delta scale" read only by opt-in presentation code; and (2) every new particle effect must use CPUParticles2D, never GPUParticles2D, because this project's gl_compatibility renderer does not support the compute shaders GPUParticles2D depends on, and particles will silently fail to render with no error. A third cross-cutting risk is over-juicing and swarm-volume breakdown (damage-number spam, additive/uncapped screen shake, sound-pool starvation, node leaks over a 15-minute loop) — the mitigation pattern (pooling, trauma accumulators, reserved audio voices, intensity scaling by hit significance, defensive cleanup backstops) should be built as shared foundational utilities before any of the ~10 individual juice effect types are implemented, not retrofitted after a swarm playtest reveals the problem.

## Key Findings

### Recommended Stack

The "stack" for this milestone is almost entirely built-in Godot 4.6 engine APIs used in ways that match conventions already established in this codebase, plus a small number of new hand-rolled reusable scripts. No third-party addons, no new packages — the project deliberately has zero entries in an addons/ folder and this milestone should preserve that.

**Core technologies:**
- Tween (create_tween()) — procedural one-off animation (scale pop, fade, position float, ring expand) — already the project's established juice tool (_show_dash_shockwave); supports set_ignore_time_scale() so UI juice can run smoothly through a hit-stop dip.
- CPUParticles2D (never GPUParticles2D) — all new particle bursts (hit sparks, death burst, level-up, evolution stinger, pickup pop) — the only particle node that reliably renders under this project's gl_compatibility renderer; matches existing heal/driver-sparkle effects exactly.
- Engine.time_scale + SceneTree.create_timer(..., ignore_time_scale=true) — explicitly not recommended for hit-stop in this networked context (see Pitfalls); the 4-arg create_timer signature is only relevant if a purely single-process cosmetic timer needs to survive a local scale dip.
- Hand-rolled trauma-based Camera2D shake — Godot 4 has no built-in shake API; each Player.tscn already owns its own Camera2D enabled only for the local authority peer, so shake is naturally local/per-client already.
- AnimationPlayer — reserved for the one authored, non-parametric sequence (evolution stage transform); Tween handles everything else that's parametric/ad hoc.
- Label/RichTextLabel — floating damage numbers and pickup text, spawned as siblings under the persistent Game node (mirrors _show_dash_shockwave's game.add_child(ring) pattern).
- Extended autoloads/Sfx.gd pool — one new method per juice moment in the existing 12-voice round-robin pattern; consider bumping pool size (~18-20) and/or reserving priority voices for must-hear stingers (kill fanfare, evolution, downed/revive) so they aren't stolen by routine hit sounds during busy fights.

New hand-rolled scripts to add: autoloads/Juice.gd (or JuiceManager.gd) as the single facade/integration point for every juice moment; scenes/fx/CameraShake.gd; scenes/fx/FloatingNumber.tscn; a persistent FxLayer/Node2D container under Game.tscn for despawn-adjacent effects.

### Expected Features

This is a well-established genre pattern (Vampire Survivors, Brotato, Deep Rock Galactic, Vermintide) cross-checked directly against this project's actual call sites, not just genre theory.

**Must have (table stakes / P1 — foundational, everything else reuses these patterns):**
- Floating damage numbers (pooled, capped concurrent count)
- Player hit-flash + screen shake (magnitude-capped) + health bar flash
- Hit-stop on kill (local/cosmetic only) + death particle burst
- XP orb magnetism + delayed "travel to bar" HUD update
- Sound cue pairing for all of the above (proves the onset-vs-tick discipline early)

**Should have (P2 — full milestone scope, builds on P1 patterns):**
- Pickup collection pop/bounce/floating text (weapon/car-part pickups)
- Level-up burst + card overlay pop-in
- Ability juice: dash trail, aura pulse, heal sparkle, drone deploy
- Enemy spawn-in telegraph effect
- Downed/revive juice broadcast to all players (wires already-stubbed but unused GameEvents.player_downed/player_revived signals)
- Evolution stage transform as a capped (~1–1.5s), non-blocking "closure moment" — deliberately sequenced last

**Defer / anti-features (explicitly do NOT build):**
- Long/global hit-stop or slow-mo via Engine.time_scale (>150-200ms) — breaks the authoritative simulation
- Multi-second evolution cutscene with camera lock/input freeze — denies agency to teammates still fighting live
- Uncapped/additive screen shake from simultaneous multi-source hits — nauseating for players and worse for the passive projected demo audience
- Damage-number spam with no pooling/aggregation
- A sound cue fired on every tick of continuous effects (burn DoT, Earth heal-aura) rather than on onset only
- Flat, identical feedback intensity for every hit regardless of significance (causes habituation)
- Accessibility settings (shake intensity toggle) — flagged as worth a lightweight version given the live-audience demo context, but not required for v1.1

### Architecture Approach

The recommended architecture layers a new, purely local JuiceManager/Juice.gd autoload underneath two existing, already-proven patterns: Pattern A (local-reactive state-diff) — the default, zero-new-RPC approach, extending the exact _last_hp_seen/_last_health_seen idiom already in Enemy.gd/Player.gd to drive damage numbers, hit-flash, HP-bar flash, downed collapse, evolution-trigger, and ability juice; and Pattern B (RPC-broadcast trigger) — reserved for the minority of effects where no replicated field carries the needed data (a new GameEvents.emit_big_hit(pos)) or where a single-target RPC must become team-visible (widening Player.set_revive_progress from rpc_id to a broadcast — safe because Player nodes have deterministic cross-peer names, unlike Enemy/Bullet). Pattern C (local opt-in hitstop scale) is the answer to hit-stop: a plain per-process float (hitstop_timer/cosmetic_delta()) read only by presentation code, never touching Engine.time_scale or SceneTree.paused, and never read by gameplay code (movement, AI, cooldowns, RPC dispatch).

**Major components:**
1. JuiceManager/Juice.gd (new autoload) — local, non-networked execution of every cosmetic effect (shake, cosmetic hitstop scale, damage numbers, flash tweens, particle bursts); has no RPCs of its own in the common case.
2. GameEvents.gd (existing, extended) — broadcast channel for discrete named/positional events (big_hit(pos)), following its existing emit_hud/emit_driver_mode reliable-broadcast pattern — extend, don't fragment into a parallel signal bus.
3. scenes/vfx/ / scenes/fx/ (new folder) — centralized, parametrized particle/flash/floating-text builders, replacing the two near-duplicate ad hoc CPUParticles2D builders already in Player.gd.
4. Modified Enemy.gd, Player.gd, XpOrb.gd, PlayerHUD, Game.gd — surgical hook additions at existing diff-watch/RPC sites, no structural rewrites.
5. A discovered pre-existing gap that must be fixed as part of this milestone, not after: Enemy's burn/slow status tints are set host-only and likely invisible on clients today (no synced flag backing them) — add is_burning/is_slowed to the replicated field set before building the fire/ice/earth elemental hit VFX this milestone explicitly wants, or the new VFX inherits the same bug.

### Critical Pitfalls

1. Engine.time_scale for hit-stop silently breaks bullet-position trust across peers and produces an asymmetric host/client experience — never call it anywhere in this project; implement hit-stop as a local-only cosmetic scale (animation speed_scale, camera micro-freeze) that never touches physics/movement/ability timers/bullet simulation.
2. GPUParticles2D silently fails to render (no error) under this project's gl_compatibility renderer — use CPUParticles2D exclusively for every new effect, exactly matching the existing heal/driver-sparkle convention.
3. Reflexively adding a new RPC per hit floods the network, but relying on diff-watch for despawn-adjacent effects (death burst) races the node's own queue_free() — reuse the free diff-watch pattern for damage/hit-flash/tint, but trigger death-burst/evolution/downed-revive via an explicit RPC carrying global_position, fired before despawn, never assuming the dying node will still exist next frame.
4. Parenting a transient juice node to the thing that triggered it (a dying enemy, a consumed orb) gets it destroyed mid-animation — always capture global_position first and parent transient VFX to a persistent container (Game/new FxLayer), never to the trigger source, matching the existing _show_dash_shockwave precedent.
5. Damage numbers, screen shake, and the shared 12-voice sound pool all break down under Vampire-Survivors-style simultaneous hit volume (3 players × up to 6 weapons, swarm waves) — must be pooled/aggregated/trauma-accumulated/priority-voiced from the start as shared foundational utilities, not retrofitted after a late-loop swarm playtest reveals unreadable screens or stolen "must-hear" stingers.
6. Orphaned Tween/particle/label nodes accumulate over a full ~15-minute loop if any of the ~10 new effect types omits a matching cleanup path — centralize spawn+cleanup in shared helpers, add a defensive backstop timer alongside every signal-based cleanup, and soak-test a full-length session on both host and client roles independently before considering any effect "done."

## Implications for Roadmap

This milestone builds on top of an already-complete core game (multiplayer netcode, roles/elements, combat, progression) — per the existing project's own conventions, this juice work should be sequenced as additive polish phases that never touch authoritative game state, only presentation.

### Phase 1: Foundational Juice Infrastructure
**Rationale:** Every other phase depends on shared primitives (the diff-watch-vs-RPC decision table, the cosmetic hitstop scale, the CPUParticles2D-only rule, a persistent FxLayer container, pooled/backstopped cleanup) existing correctly and consistently before ~10 individual effect types are built on top of them — building this foundation last or ad hoc per-effect guarantees at least one effect reinvents (and gets wrong) Engine.time_scale, GPUParticles2D, or leaked nodes.
**Delivers:** JuiceManager/Juice.gd autoload (shake, cosmetic_delta()/hitstop, spawn_damage_number, flash, particle-burst factory), scenes/vfx/ scene stubs, persistent FxLayer node under Game.tscn, damage-number object pool, trauma-based shake accumulator, extended/reserved-voice Sfx.gd pool. No gameplay-file edits yet — buildable and testable in isolation.
**Addresses:** Cross-cutting prerequisites for every P1/P2 feature in FEATURES.md.
**Avoids:** Pitfalls 1, 2, 5, 6 (time_scale misuse, GPUParticles2D silent failure, swarm-volume breakdown, orphaned nodes) — all explicitly flagged as "must be decided/built before any consuming effect."

### Phase 2: Combat Feedback (Local-Reactive Core Loop)
**Rationale:** The highest-value, lowest-risk work — entirely Pattern A (diff-watch on already-replicated current_hp/health), zero new RPCs, directly extends the codebase's own proven _last_hp_seen/_last_health_seen idiom.
**Delivers:** Floating damage numbers, player/enemy hit-flash, screen shake + HP-bar flash on player damage, hit-stop on kill (using the Phase 1 cosmetic scale), death particle burst (Pattern B: RPC-before-queue_free(), global_position captured, parented to FxLayer).
**Addresses:** P1 features — floating damage numbers, hit-flash+shake+HP-bar-flash, hit-stop+death burst.
**Avoids:** Pitfall 3 (RPC-per-hit flooding vs. despawn race) and Pitfall 4 (parenting to trigger source) — this phase is the first real consumer of the death-burst-before-despawn rule.

### Phase 3: Collection & Progression Feedback
**Rationale:** XP orb magnetism must exist before "travel to bar" can be built on top of it (the fly-to-bar handoff needs an already-"attracted" orb state to transition from) — sequencing this after Phase 2 lets it reuse the pooling/tween patterns just proven out.
**Delivers:** XP orb magnetism (ghost-clone cosmetic flight, real collection RPC untouched), HUD bar decoupled to animate up on arrival rather than snap instantly, pickup pop/bounce/floating text (reusing damage-number pooling infra), level-up burst + card pop-in animation.
**Addresses:** P1 (XP magnetism+travel-to-bar) and early P2 (pickup pop, level-up burst) features.
**Uses:** Tween-based ghost-clone magnetism (STACK.md recommended alternative over fully synced orb movement) — deliberately avoids adding new networked node state for a cosmetic-only ask.

### Phase 4: Status-Effect Sync Fix + Elemental/Ability Juice
**Rationale:** The discovered burn/slow client-visibility gap must be fixed before building fire/ice/earth hit VFX, or the new VFX silently inherits the same "only visible on host" bug — this is a small, targeted, low-risk fix that unblocks the differentiator feature.
**Delivers:** is_burning/is_slowed added to Enemy's synced fields (read in _process, gameplay math untouched/host-only); element-specific hit VFX (fire scorch/ice shatter/earth crack) tied to the CARIAD car-metaphor HUD indicators; ability juice (dash trail, aura pulse, heal sparkle, drone deploy); enemy spawn-in telegraph.
**Implements:** Architecture's "Status-Effect Visibility Gap" fix, Pattern A extended to ability-state diffs (shield_active, dash_invincible).

### Phase 5: Downed/Revive + Team-Wide Broadcast Juice
**Rationale:** This is the one explicit user requirement most distinct from generic single-player genre advice (co-op "everyone sees it" moments) and the plumbing (GameEvents.player_downed/player_revived) is already scaffolded but unwired — natural, cheap, idiomatic slot to finally connect it.
**Delivers:** Downed collapse animation, revive progress ring widened from single-target rpc_id to a team-visible broadcast, revive success burst, wired player_downed/player_revived signal emission.
**Addresses:** P2's highest-user-value item (downed/revive team-visible juice), explicitly called out as a differentiator in FEATURES.md.

### Phase 6: Evolution Transform Closure Moment
**Rationale:** Deliberately sequenced last — it composes hitstop + shake + particles + sound + broadcast simultaneously, so it's easiest to get right only once every individual primitive from Phases 1-5 is already validated in isolation. Also the highest agency-risk feature (must stay capped ~1-1.5s, non-blocking, no input freeze, since teammates are still fighting live).
**Delivers:** Flash → burst → sprite-swap → hold → release sequence via AnimationPlayer, screen-space effects gated to is_multiplayer_authority() only, particle/model-transform visible to all peers (character node already broadcast today).
**Addresses:** P2's highest-complexity differentiator feature.

### Phase 7: Full Sound Pass + Soak-Test / Swarm Playtest
**Rationale:** Cross-cutting — fastest to do once every visual hook point from Phases 2-6 already exists, rather than interleaved per-phase. Also the natural place for the milestone's mandatory validation: this is a networked, volume-sensitive feature set that "looks done" in light solo testing but breaks under real conditions.
**Delivers:** Sfx/Music cue attached to every hook added in Phases 2-6 (onset-only for continuous effects, reserved/priority voices for must-hear stingers); a genuine ~15-minute continuous-loop soak test watching node count on host and client independently; a late-loop 2-3-real-peer swarm playtest checking damage-number/shake readability and audible stingers under heavy simultaneous fire.
**Avoids:** Pitfall 5 (swarm breakdown) and Pitfall 6 (node leaks) verification gap — these are explicitly "invisible in short/solo testing" failure modes per PITFALLS.md.

### Phase Ordering Rationale

- Foundation before consumers: every pitfall source (STACK, ARCHITECTURE, PITFALLS) independently converges on the same conclusion — decide the hitstop mechanism, particle node type, RPC-vs-diff-watch rule, and cleanup pattern exactly once, in a phase with no gameplay-file edits, before ~10 individual effects each risk reinventing (and getting wrong) the same decisions.
- Combat before collection before ability/elemental before team-broadcast before evolution: this mirrors both the FEATURES.md MVP sequencing (P1 → P2) and the ARCHITECTURE.md "Suggested Build Order" (steps 1-7), and follows a genuine technical dependency chain: XP travel-to-bar needs magnetism first; elemental hit VFX needs the status-sync fix first; evolution needs hitstop+shake+particles+sound all independently proven first.
- Multiplayer-specific pitfalls (time_scale asymmetry, RPC despawn races, per-peer leak differences) are invisible in solo testing — this is why validation/soak-testing is pulled out as its own explicit phase rather than assumed to happen "along the way"; PITFALLS.md is explicit that these bugs only appear "the moment a second peer is involved — which is this game's actual primary use case."

### Research Flags

Phases likely needing deeper research during planning:
- Phase 1 (Foundational Infrastructure): the trauma-accumulator shake formula and damage-number aggregation/pooling thresholds are referenced via community sources (Squirrel Eiserloh's GDC talk, kidscancode recipe) but not yet tuned for this specific project's hit rates — worth a focused pass during planning to pick concrete numeric constants (trauma decay rate, aggregation window ms, pool sizes).
- Phase 4 (Status-Effect Sync Fix): touches SceneReplicationConfig/sync-set configuration directly — verify the exact mechanism for adding new synced booleans to Enemy.gd against the current MultiplayerSynchronizer setup before assuming it's a one-line addition.
- Phase 6 (Evolution Transform): highest complexity, combines every primitive — worth a short design-review pass on exact sequence timing/duration before implementation, given the explicit agency-risk warning (must not feel like a cutscene).

Phases with standard, well-documented patterns (skip research-phase):
- Phase 2 (Combat Feedback): directly extends an existing, working, already-understood codebase pattern (_last_hp_seen-style diff-watch) — no new unknowns.
- Phase 3 (Collection & Progression): ghost-clone cosmetic tween approach is explicitly recommended over synced magnetism specifically because it requires no new netcode surface.
- Phase 5 (Downed/Revive Broadcast): the RPC pattern to reuse (GameEvents reliable broadcast) is already implemented and proven elsewhere in the same file.
- Phase 7 (Sound Pass): mechanically identical to the existing Sfx.gd extension pattern already used for shoot()/hit().

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Grounded in official Godot 4.6 docs (verified GPUParticles2D Compatibility-renderer restriction, Engine.time_scale scope, Tween/SceneTree.create_timer signatures) cross-checked against direct reads of this project's actual .gd files. A few judgment calls (ghost-clone vs. fully-synced XP magnetism, AnimationPlayer vs. Tween-chain for evolution) are explicitly flagged as recommendations, not requirements. |
| Features | HIGH | Established genre domain (Vampire Survivors, Brotato, Deep Rock Galactic, Vermintide) with decades of design precedent, cross-checked against this project's actual call sites (Player.gd, Enemy.gd, XpOrb.gd, PlayerHUD.gd) rather than genre theory alone. Some sources (Wayline blog posts on over-juicing) are MEDIUM-confidence blog-level critique rather than primary/academic sources, though corroborated by an arXiv game-feel survey. |
| Architecture | HIGH | Grounded directly in reading Player.gd, Enemy.gd, Bullet.gd, XpOrb.gd, GameEvents.gd, GameState.gd, Game.gd, project.godot — the core findings (diff-watch pattern, non-deterministic Enemy/Bullet node naming, host-only-gated functions) are verified ground truth, not inference. Engine-mechanics claims (MultiplayerSpawner per-peer callback execution, SceneTree.paused semantics) verified against official docs. |
| Pitfalls | HIGH | Same direct-codebase-reading basis as Architecture, cross-checked against official docs (GPUParticles2D, SceneTree pausing tutorial) and community sources (Godot forums, GitHub issues) for corroboration. Community forum threads are individually MEDIUM confidence but the underlying technical claims (time_scale being process-global, GPUParticles2D failing under Compatibility) are independently corroborated by multiple sources plus official docs. |

**Overall confidence:** HIGH

### Gaps to Address

- Ghost-clone XP magnetism vs. fully synced magnetism: STACK.md explicitly recommends the cosmetic-only ghost-clone approach for this milestone as a deliberate demo-deadline risk tradeoff, not a definitive "correct" answer — validate during playtesting whether purely cosmetic flight (fixed capture radius, no true "chase" behavior) feels satisfying enough, or whether the team wants to revisit with true synced magnetism in a later milestone.
- 20 Hz replication-tick granularity for damage numbers: simultaneous multi-bolt hits landing within one ~50ms sync tick will under-count as a single merged number rather than several distinct ones. All four research files agree this is an acceptable, known limitation for a demo — flag it explicitly as accepted scope rather than a bug, but revisit with Pattern B (explicit per-hit RPC) if playtesting shows it reads wrong.
- Status-effect visibility gap is a discovered pre-existing bug, not an explicit v1.1 requirement: confirm with the team that fixing is_burning/is_slowed client-visibility is in scope for this milestone (strongly recommended, since the elemental hit VFX feature would otherwise silently inherit it) rather than deferring it as separate technical debt.
- Sound pool sizing/priority scheme is not yet concretely specified: STACK.md suggests bumping POOL_SIZE from 12 to ~18-20; PITFALLS.md suggests a separate reserved/priority voice scheme for must-hear stingers. These are two different mitigations for the same problem — pick one (or both) concretely during Phase 1 planning rather than leaving it ambiguous.
- Accessibility settings (shake intensity/off toggle): explicitly deferred to "future consideration" in FEATURES.md but flagged as worth a lightweight version given the live-audience/projected-demo context noted in PROJECT.md — needs an explicit scope decision (in v1.1 vs. deferred) rather than silently dropping it.

## Sources

### Primary (HIGH confidence)
- Direct codebase reads: project.godot, scenes/Player.gd, scenes/enemies/Enemy.gd, scenes/projectiles/Bullet.gd, scenes/pickups/XpOrb.gd, autoloads/Sfx.gd, autoloads/GameEvents.gd, autoloads/GameState.gd, scenes/Game.gd, scenes/ui/PlayerHUD.gd, scenes/ui/CarHUD.gd, scenes/ui/CardOverlay.gd, .planning/PROJECT.md
- Godot 4.6 official docs — GPUParticles2D, Engine, Tween, SceneTree class references: https://docs.godotengine.org/en/4.6/
- Godot official docs — Pausing games and process mode: https://docs.godotengine.org/en/latest/tutorials/scripting/pausing_games.html
- Godot official article — Multiplayer in Godot 4.0: Scene Replication (confirms MultiplayerSpawner.spawn_function runs independently per peer): https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/
- Xbox Accessibility Guideline 118 (adjustable screen shake): https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118
- Game Accessibility Guidelines — flickering/repetitive patterns: https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/

### Secondary (MEDIUM confidence)
- godotengine/godot GitHub issues on GPUParticles2D + Compatibility renderer: #85945, #84072, #102634
- Godot Forums — hit-stop and frame-freeze-without-pausing discussions
- kidscancode.org "Screen Shake" recipe and Shaggy Dev "Better screen shake" (trauma-accumulator technique, tracing to Squirrel Eiserloh's GDC talk)
- Wayline blog series on over-juicing / juice fatigue
- arXiv:2011.09201 "Designing Game Feel: A Survey"; arXiv:2208.06155 "What Features Influence Impact Feel?"
- Kokutech Vampire Survivors design analysis; Vampire Survivors Fandom wiki (Magnet mechanic); Deep Rock Galactic Fandom wiki (Health/revive)

### Tertiary (LOW confidence)
- Fatshark Forums community discussion of Vermintide/Darktide revive-feedback design (single community thread, not corroborated elsewhere)
- Individual Godot forum threads on Engine.time_scale/timer interaction quirks (community reports, not resolved to one canonical documented answer)

---
*Research completed: 2026-07-13*
*Ready for roadmap: yes*
