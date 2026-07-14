# Phase 11: Whole-Game Sound Design Pass & Soak-Test Validation - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

A full sound design pass across the *entire* game (not just Phase 10's new juice moments) plus a real multiplayer soak/swarm validation. Today only two cues exist (`shoot()`/`hit()` in `autoloads/Sfx.gd`). This phase:

1. Produces a complete audio-parts checklist (every Phase 10 juice moment + every currently-silent existing action) for the team to source real files against.
2. Wires the trigger-point plumbing for each cue as files become available — extends `Sfx.gd`'s pool/safe-load pattern, adds a priority-voice scheme, and adds a small set of reactive music moments to `Music.gd`.
3. Validates the whole v1.1 milestone with a genuine ~15-minute continuous-loop soak test (host + client) and a 2–3-real-peer swarm playtest.

This is trigger-plumbing and validation, not audio content authoring — actual WAV/audio files depend on human input from the team. The safe-load pattern means wiring can proceed ahead of asset delivery (missing file degrades to silence, not a crash).

**Not in Phase 11 scope:**
- Camera-behavior cleanup (follow-cam remnants, zoom/overview decision) — Phase 10 flagged this as deferred "to Phase 11," but on review the user chose to leave it deferred further rather than fold it into this phase's written ROADMAP scope. It remains an unscoped backlog item — see Deferred Ideas.
- Any authoritative gameplay change — purely additive presentation/audio layer, same discipline as Phase 10.

</domain>

<decisions>
## Implementation Decisions

### Voice Pool & Priority Scheme
- **D-01:** Both — bump the flat `POOL_SIZE` (currently 12) up toward the ROADMAP's suggested ~18–20 range, **and** carve out a reserved subset of those voices that only priority cues can use (never stolen by routine shoot/hit sounds).
- **D-02:** The priority set is **7 cues**: kill fanfare, evolution transform, downed, revive, boss phase-change, boss death, and big hit/level-up (the ≥15-dmg big-hit broadcast and the level-up burst share priority status as team-visible co-op moments).
- **D-03:** Exact total pool size and how many voices are reserved is **Claude's discretion** — target is "priority cues never silently drop under swarm load," not a specific number. Reserved voices don't need to be one-per-cue-type; the 7 priority cues can round-robin among the small reserved set since they rarely all fire simultaneously.
- **D-04:** Overflow behavior — if two priority cues fire at once and all reserved voices are busy, the newer one **steals a voice from the shared/routine pool** rather than being dropped silently. Guarantees priority cues are effectively always audible, at the acceptable cost of occasionally cutting off a routine hit sound.

### Car-Theme Sound Direction
- **D-05:** Split treatment: weapons, pickups, and vehicle-y abilities (e.g. Tank shield, boss mech sounds) lean into the **CARIAD car-part theme** (metallic clunks, engine revs, horn honks, electronic beeps, servo whirs). Elemental FX (Fire/Ice/Earth) and organic effects (heal sparkle) are **not** forced into the car metaphor generically — see D-06 for the specific elemental exception.
- **D-06:** Elemental sound cues **echo the existing HUD car-framing** rather than going generic/magical: Ice → AC-compressor hiss (matches "AC ❄️ COLD"), Fire → engine-overheat hiss/rattle (matches "ENGINE 🔥 OVERHEAT"), Earth heal → soft servo/massage-chair hum (matches "SEAT MASSAGE 🌿 ACTIVE"). This reinforces the one CARIAD framing bit that's already consistent in the game, rather than treating sound and HUD text as unrelated layers.
- **D-07:** UI/menu sound style (punchy comic-matched vs. subtle standard blips) is **Claude's discretion**, using `Sfx.gd`'s existing doc comment ("deliberately quiet... subtle feedback cues, not the focus of the mix") as the tiebreaker when the checklist is written.

### Music Layer Scope
- **D-08:** This phase **does** reach into `Music.gd`, not just one-shot SFX — a small number of key moments get a music-layer reaction layered on top of the ongoing lobby/in-game shuffle (not replacing it).
- **D-09:** Exactly two moments get music treatment: **evolution transform** (brief swell/intensity bump under the existing ~1–1.5s closure moment, pairing with the flash/particle/slow-mo already locked by Phase 10's PROG-03) and **boss death / loop-end** (a resolve, marking the climax before the next harder loop starts). **Boss phase-change explicitly stays SFX-only** (no music duck/sting) — the user selected the other two moments but not this one.

### Continuous-Tick Sound Treatment
- **D-10:** SFX-02 already locks onset-only for Fire burn DoT and Earth passive heal tick (given, not re-decided here).
- **D-11:** Spinning Tires' continuous orbit-contact damage (0.5s per-enemy cooldown) — treatment is **Claude's discretion**, defaulting toward onset-only/throttled for swarm readability unless implementation clearly reads worse.
- **D-12:** Ice trail zone's continuous slow-on-contact — treatment is **Claude's discretion**, defaulting toward onset-only for consistency with the rest of the continuous-effect discipline (D-11, SFX-02).

### Claude's Discretion
- Exact `POOL_SIZE` number and reserved-voice count (D-03)
- UI/menu sound style — punchy comic vs. subtle (D-07)
- Spinning Tires and Ice trail zone tick-vs-onset treatment (D-11, D-12), default onset-only
- Full audio-parts checklist composition and per-cue sound character within the D-05/D-06 style rules
- Technical implementation of the reactive music layer (duck/sting/fade mechanics, whether it's a second AudioStreamPlayer or a modification to the existing shuffle player)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 11 — goal, suggested internal sequencing (checklist → plumbing → soak test → swarm test), success criteria, pitfall watch (explicitly flags the voice-pool/priority decision this discussion resolved)
- `.planning/REQUIREMENTS.md` §v1.1 Sound Design — SFX-01–03 full text; SFX-02's onset-only rule for continuous effects

### Project & Milestone Context
- `.planning/PROJECT.md` — CARIAD HUD core value, v1.1 milestone goal (paired sound on every juice moment)
- `.planning/STATE.md` — Accumulated Context / Decisions bullet on Phase 11 scope broadening (SFX-03) and the open voice-pool/priority-scheme flag this discussion resolved

### Prior Phase Architecture
- `.planning/phases/10-juicy-feedback-visual-gameplay-polish/10-CONTEXT.md` — D-16 (≥15-dmg big-hit threshold reused for priority-cue set), D-17 (no scrolling camera — informs why camera cleanup was left deferred rather than folded in), the camera-cleanup deferred-idea entry this phase's domain section responds to

### Live Code (read before modifying)
- `autoloads/Sfx.gd` — 12-voice round-robin pool, safe-load `_try_load()` pattern, existing `shoot()`/`hit()` — the pattern to extend for pool bump + priority reservation (D-01–D-04)
- `autoloads/Music.gd` — `play_menu()`/`play_lobby()`/`play_ingame()` shuffle, `_play_single`/`_play_shuffle`/`_play_path` internals — the integration point for the two reactive music moments (D-08, D-09)
- `autoloads/GameEvents.gd` — `hud_event`, `driver_mode`, `player_downed`/`player_revived`, `big_hit` RPCs already broadcast to all peers; a central Sfx/Music listener can hook these instead of scattering calls at each site
- `scenes/weapons/WeaponManager.gd` + `scenes/weapons/*.gd` (ExhaustFlames, SpinningTires, AntennaBeam, HornShockwave, AirbagShield) — fire-timer and damage-tick call sites, all currently silent
- `scenes/Player.gd` — `_use_stage1_ability()`/`_use_stage2_ability()`, `_do_dash()`, `_use_second_dash()`/`_spawn_dash_shockwave()`, `_activate_shield()`/`_hide_shield_ring()`, `_request_reflect()`, `_fire_burst()` (Fire), `_tick_element()` (Ice) — role/elemental ability call sites
- `scenes/roles/HealDrone.gd` — `_spawn_deploy_effect()`, `_on_pulse()` (heal tick, onset-only per existing SFX-02 precedent)
- `scenes/elements/IceTrailZone.gd` — `_on_enemy_entered()`, the continuous-slow zone from D-12
- `scenes/Game.gd` — `_tick_earth_effects()` (heal tick + shockwave), `_show_earth_shockwave()`, `_transition_to_room()`, `_transition_to_sub_room()`, `_open_exit_passage()`, `_on_boss_died()` → `GameState.start_next_loop()`, `_run_start_countdown()` — transition/loop call sites
- `scenes/pickups/XpOrb.gd` — `_request_collect()`, `_spawn_collection_dart()` / `PlayerHUD.arrive_xp()` — XP pickup arrival cue site
- `scenes/ui/MainMenu.gd`, `scenes/ui/LobbyScreen.gd`, `scenes/ui/CardOverlay.gd`, `scenes/ui/GameOver.gd` — all button/navigate/confirm handlers currently silent
- `scenes/enemies/Boss.gd` — `_enter_phase()`/`_notify_phase_change()`, `_fire_volley()`, melee-charge block in `_physics_process()`, `take_damage()` death branch — boss event call sites
- `autoloads/GameState.gd` — `start_next_loop()` (loop-end/loop-start transition point)

### Assets
- `assets/audio/sfx/` — currently `shoot.wav`, `hit.wav` only
- `assets/audio/` — existing music tracks (`Erba_1.wav`, `Erba_2.wav`, `Theme_1.wav`, `Lobby_1.wav`, `ingame.mp3`, `lobby.mp3`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sfx.gd`'s round-robin pool + `_try_load()` safe-load pattern — the backbone to extend with a priority-voice subset, not replace
- `Music.gd`'s single/shuffle dual-mode player — extends naturally to a third "sting/swell" mode without disrupting the ongoing shuffle
- `GameEvents.gd`'s existing broadcast RPCs (`hud_event`, `player_downed`/`player_revived`, `big_hit`) — central hook points for a sound listener, avoiding scattered calls for those specific events

### Established Patterns
- Safe-load discipline (`ResourceLoader.exists()` check before `load()`) — every new cue call site must follow this so missing team-sourced files degrade to silence, never a crash
- Onset-only cue discipline for continuous/repeating effects (SFX-02) — now extended by user decision to Spinning Tires and Ice trail zone (Claude's discretion, default onset-only)
- Host-authoritative gameplay, presentation-only additions — sound/music wiring never changes game state, consistent with Phase 10's discipline

### Integration Points
- Every weapon/ability/element script listed in canonical_refs needs a direct `Sfx.xxx()` call inserted at its existing trigger function — no new signals required for most of these (categories 1–3, 6–7 per the codebase scout have no signal at all today)
- `GameEvents`'s 4 existing broadcast RPCs are candidate central hook points rather than per-site calls
- `Music.gd` needs a new code path for the two reactive moments (D-09) that layers over `_play_shuffle`/`_play_single` without interrupting the ongoing track

</code_context>

<specifics>
## Specific Ideas

- **The HUD-echo insight (D-06):** the game already frames elements as car systems in its HUD text (AC COLD, ENGINE OVERHEAT, SEAT MASSAGE) — the user chose to carry that exact framing into the sound design rather than treating audio and HUD flavor text as independent layers. This is the throughline for the whole audio-parts checklist's elemental section.
- **Priority-cue set is fixed at 7:** kill fanfare, evolution transform, downed, revive, boss phase-change, boss death, big hit/level-up. Use this exact list when writing the checklist's priority tier and when implementing the reserved-voice scheme.
- **Music reacts to exactly 2 moments, not 3:** evolution transform and boss death/loop-end get a music-layer reaction; boss phase-change was explicitly left SFX-only when offered as a third option.

</specifics>

<deferred>
## Deferred Ideas

- **Camera-behavior cleanup** (follow-cam remnants, zoom/overview decision) — Phase 10 flagged this as deferred "to Phase 11," but this discussion's first question confirmed the user wants it left deferred further rather than folded into Phase 11's written ROADMAP scope. Still an unscoped backlog item for a future phase or standalone task.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned zero matches for Phase 11.

</deferred>

---

*Phase: 11-whole-game-sound-design-pass-soak-test-validation*
*Context gathered: 2026-07-14*
