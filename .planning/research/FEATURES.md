# Feature Research

**Domain:** Game-feel / "juice" feedback systems for a co-op LAN action-roguelike (Vampire-Survivors-style progression + top-down bullet-heaven combat)
**Milestone:** v1.1 Juicy Feedback (supersedes the v1 FEATURES.md research below — that milestone's core systems are now built; this file covers ONLY the new juice/game-feel layer)
**Researched:** 2026-07-13
**Confidence:** HIGH (established game-feel design domain with decades of precedent — Vampire Survivors, Enter the Gungeon, Deep Rock Galactic, Vermintide — cross-checked against this project's actual `scenes/*.gd` call sites, not just genre theory)

## Feature Landscape

### Table Stakes (Users Expect These)

Features players in this genre assume exist. Missing these makes hits feel weightless and progression feel invisible — the exact complaint "juicy feedback" milestones exist to fix.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Floating damage numbers on enemy hit | Universal in Vampire-Survivors-likes and action-RPGs; confirms a hit landed and communicates relative damage at a glance | LOW | Cosmetic-only — spawn as a local `Label`/`Node2D` on the peer that already sees the health change; does NOT need to be an authoritative synced node. Hooks off `Enemy.take_damage()` (`scenes/enemies/Enemy.gd:151`) and `Player.receive_damage()` (`scenes/Player.gd:714`). At 6 simultaneous weapons + high enemy density, numbers WILL overlap — needs pooling and a stacking/merge rule (see Anti-Features) |
| Player hit-flash (sprite tints red/white briefly) | Standard "ouch" signal in every action game; without it damage is easy to miss mid-combat | LOW | `modulate` flash via `Tween`, triggered from `receive_damage()` on the owning peer only (local visual, never synced) |
| Screen shake on taking damage / big hits | Adds weight to impacts; genre convention since at least *Vampire Survivors*/*Brotato* | LOW–MEDIUM | Camera2D offset jitter, 0.1–0.3s, eased out. Must be local-only (each laptop is a separate process/viewport — never sync camera state over the network, confirmed existing constraint from Phase 9 pitfall notes). Needs a **magnitude cap** so simultaneous multi-hit (3 players + AoE) doesn't compound into unreadable chaos, and ideally an intensity setting given this demo is shown to a live audience |
| Health bar flash / animate-not-snap on damage | Read-at-a-glance state change; snapping instantly to new value is harder to parse than a brief flash + tween-down | LOW | `HLTH-03` already syncs `health` via `MultiplayerSynchronizer`; this is a pure presentation layer added on top of the existing synced value, no new RPC needed |
| Hit-stop (brief freeze, 3–5 frames) on kill | Best-researched impact-feedback technique (fighting/action games); gives the brain time to register the kill | MEDIUM | **Must NOT use `Engine.time_scale`** — this project is host-authoritative across separate LAN machines; slowing global time on the host would slow the authoritative simulation for every player, and slowing it on a client would desync that client's local rendering from host state. Implement as a cosmetic local pause: freeze the killed enemy's sprite/AnimationPlayer + briefly suppress the killer's own input-to-visual lag, scoped to the local peer's rendering only |
| Death particle burst | Payoff for a kill; near-universal in the genre | LOW | `CPUParticles2D`/`GPUParticles2D` one-shot, instanced locally on all peers off the existing `died` signal / `queue_free()` path (`Enemy.gd:158-160`) — needs the `queue_free()` deferred by a frame or two so there's still a node to attach the burst to (currently frees immediately) |
| Pickup magnetism (XP orbs drift toward player in range) | Table stakes since *Vampire Survivors* popularized it — "watching gems streak toward you" is cited as a core dopamine moment of the genre | MEDIUM | `XpOrb.gd` currently only detects `body_entered` (touch-to-collect, no radius pull). Needs a proximity-check tween/steer-toward-nearest-player behavior added client-side (purely cosmetic movement — the actual collection RPC/host validation in `_request_collect` is unchanged) |
| Pickup collection pop/bounce + floating "+X" text | Confirms value gained; used for both XP orbs and car-part weapon pickups | LOW | Mirrors damage-number pooling approach; reuse the same floating-text system for both XP and pickups |
| XP orb "travel to bar" before value updates | User-specified requirement, but also standard practice in modern bullet-heavens (Brotato, Halls of Torment) to visually connect world-space pickup to UI-space bar fill | MEDIUM–HIGH | **Key architecture finding:** `GameState.add_team_xp()` / `PlayerHUD.update_hud()` (`scenes/ui/PlayerHUD.gd:36-44`) currently apply and *display* XP instantly (bar `.value` snaps). The authoritative XP grant should stay instant (no network protocol change) — only the **local HUD bar fill** needs to lag behind and animate up once a client-local "orb reached the bar" cosmetic sprite finishes its flight. This decouples game-state truth (host-authoritative, instant) from presentation (client-local, delayed), avoiding any new sync complexity |
| Level-up burst + card overlay pop-in animation | Card pick is already a core loop event (Phase 6); needs a "moment" so it reads as a reward, not an interruption | LOW–MEDIUM | `CardOverlay.gd` already exists as a non-blocking local `CanvasLayer` (W4 constraint: never `SceneTree.paused`) — juice is additive animation on entry (scale/fade pop-in), not new logic |
| Enemy spawn-in effect (telegraph) | Lets players react instead of enemies "popping" fully solid; also ties into existing LIDAR HUD indicator (enemy spawn already fires `emit_hud("lidar")`) | LOW | Fade-in/scale-in on `Enemy._ready()`, purely cosmetic, all peers render it identically since spawn is already host-authoritative + `MultiplayerSpawner`-synced |
| Downed collapse animation + revive progress ring | HLTH-04/05/06 already implement the downed/revive state machine; without visual weight, "downed" currently reads as just a color tint (`Sprite.modulate = Color(0.4,0.4,0.4)`, `Player.gd:813`) | LOW–MEDIUM | Builds directly on existing `_enter_downed()`, `revive()`, `set_revive_progress()` (`Player.gd:970-996`) |
| Paired sound cue for every juice moment | User explicitly requires audio on every juice event, not just impacts — matches game-feel theory that feedback must hit "eyes, ears, and hands simultaneously" to read as physically real | LOW per-cue, MEDIUM in aggregate | `Sfx.gd` autoload already exists with a 12-voice round-robin pool (`shoot()`, `hit()` implemented at -17dB/-13dB). Every new juice moment needs one more `Sfx.<event>()` method in the same pattern — this is the natural, low-friction extension point, not a new system |

### Differentiators (Competitive Advantage / Thematic Fit)

Features that go beyond generic genre juice and specifically reinforce this project's CARIAD-demo core value and co-op-on-LAN structure.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Team-wide broadcast juice for shared moments (healing, revival, big hits) | Most single-player game-feel guidance assumes one screen, one player. This is a 1–3 player LAN co-op demo where "my teammate got revived" or "the Earth player healed the team" should read as a shared event on every screen — directly requested by the user and distinct from generic genre advice | MEDIUM | The plumbing largely already exists and is *unused*: `GameEvents.gd` already declares `signal player_downed(player_id)` and `signal player_revived(player_id)` (lines 13, 15) marked `@warning_ignore("unused_signal")` — nobody emits them yet. Wiring these to broadcast RPCs mirrors the existing `emit_hud()` pattern (`@rpc("authority","call_local","reliable")`, `GameEvents.gd:21-23`) exactly. This is the cheapest, most idiomatic path to satisfy "visible to all players" |
| Element-specific hit VFX tied to CarHUD indicators (fire scorch, ice shatter, earth crack) | Reinforces the CARIAD "vehicle sensor" concept the whole demo is built around — juice isn't generic, it's branded to the car metaphor (fire hit = engine-overheat visual language, ice hit = AC-frost visual language) | MEDIUM | Attaches to existing element proc logic in `Bullet.gd`/`Player.gd` element ticks, which already trigger `emit_hud()` calls (HUD-03/04/05) — juice VFX/SFX ride the same trigger point, no new authority plumbing |
| Evolution transform as a full multi-sensory "closure moment" (flash + particles + brief slow-mo + stinger sound + HUD tie-in) | Genre standard (this project's own Phase 6 baseline) is just a sprite swap. Making Stage 2→3 feel like a cinematic beat is a strong differentiator for a live demo audience — but per the source material's warning, this MUST be capped short (see Anti-Features) so it reads as a "moment" not a "cutscene" | MEDIUM–HIGH | Hooks `Player.set_evolution_stage()` (`Player.gd:772-779`) — already an `@rpc("any_peer","call_remote","reliable")` that could be extended to also broadcast a cosmetic "team sees a flash over this player" event, matching the `player_downed`/`player_revived` broadcast pattern above |
| Comic-styled damage numbers / card pop-ins matching existing "Comic UI Pass" | Codebase already has a dedicated comic-book visual identity (`UiStyle.gd`, Bangers font, ink-bordered panels — see recent commit "Comic UI Pass") — new juice UI (damage numbers, floating text, card pop-in) reads as native to the game rather than bolted-on if it reuses `UiStyle.button_font()` / comic color palette | LOW | Pure consistency win, near-zero extra cost since the style system already exists |
| Intensity-scaled feedback (small hit = small juice, elite/boss hit = bigger juice) | Prevents the single most common genre complaint — flat, identical feedback for every hit trains players to tune it out (habituation). The codebase already has the exact hook needed: `from_elite` flag distinguishes big hits from normal ones (`Player.gd:714,738-753`, feeding the existing `notify_significant_hit()`/SUSPENSION HUD path) | LOW–MEDIUM | Reuse `from_elite` (and boss-hit equivalent) as the built-in "is this a big moment" signal for shake magnitude, hit-stop duration, and damage-number size/color — no new classification system needed |

### Anti-Features (Commonly Requested, Often Problematic)

The genre's own post-mortems (and this milestone's source material) specifically call out over-juicing as a failure mode: exaggerated feedback that blocks player agency, or feedback so constant it becomes noise and stops registering. Each anti-feature below maps to a documented genre pitfall.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Long/global hit-stop or slow-mo on every kill (>150–200ms, using `Engine.time_scale`) | "Bigger freeze = bigger impact" is the naive extrapolation of the hit-stop technique | In a host-authoritative LAN game, `Engine.time_scale` on the host would slow the *authoritative simulation* for all 3 players simultaneously every time anyone gets a kill — with 6 auto-firing weapons and dense enemy waves, kills happen multiple times per second, meaning the whole game would be in near-permanent slow-motion. On a client it desyncs local rendering from host truth. This is also explicitly the genre pitfall of hit-stop overuse degrading input responsiveness | Keep hit-stop to 3–5 frames (~50–80ms), implemented as a local, per-peer cosmetic pause (freeze the specific enemy's animation/sprite, not global engine time), and only for the killing blow — not for every damage tick |
| Evolution transform as a multi-second cutscene (forced camera pan, full-screen takeover, disabled input) | "It's a huge power spike, it deserves a big cinematic" | This is live 3-player co-op — while one player's screen is locked in a cutscene, their teammates are still fighting and may need help; a multi-second forced sequence for one player actively harms the other two players' experience and denies agency exactly as the source material warns. Also, evolution happens twice per run per player (Stage 2 and Stage 3) — a long sequence run 6 times across a 3-player session becomes tedious fast | Cap the transform beat to roughly 1–1.5s, non-blocking (`CanvasLayer` overlay on the transforming player's own screen only, matching the existing W4 non-blocking-UI constraint), no camera lock, no input freeze — player can still move/fight mid-flash |
| Uncapped/additive screen shake from simultaneous multi-source hits | "More shake reinforces more damage" | With 3 players each running up to 6 weapons plus AoE elemental abilities, several hit events can land in the same frame; naively summing shake offsets produces a violent, nauseating camera strobe — a real problem for a demo presented live to a projector audience, and a documented photosensitive-epilepsy/motion-sickness risk (1 in ~4,000 players) that established accessibility guidance says should be capped or made adjustable, not eliminated only via a warning screen | Clamp total shake magnitude per frame (diminishing returns/max cap regardless of how many hits land), and expose it as a toggle/intensity value the demo operator can turn down before a live audience session |
| Damage-number spam at high fire rate / high enemy density | "Every hit should show a number" — literal reading of the user's request | With 6 auto-firing weapons hitting a dense wave, dozens of numbers can spawn per second, overlapping into unreadable visual soup — a well-known genre problem in bullet-heavens once players stack enough weapons | Pool number instances (cap concurrent on-screen count), and merge/stack rapidly repeated small hits on the same enemy within a short window (e.g., accumulate into one updating number) rather than spawning one per tick |
| A sound cue fired on literally every instance of every juice event, including continuous/repeating effects (Fire burn DoT ticking every 1s, Earth team-heal ticking every 1s per ELEM-05) | User's explicit instruction: "audio cue on EVERY juice moment" | Taken completely literally, a burning enemy or an always-on Earth healer would trigger a repeating chime every second for the whole run — in a demo watched by an audience, this becomes exactly the "nuisance sound" pattern documented in game-audio design (tracked via "nuisance score" systems in AAA audio practice) and causes fatigue/annoyance rather than reinforcing an event | Pair a cue with the *onset* of continuous effects (burn applied, heal-aura activated) rather than every tick, and lean on `Sfx.gd`'s existing voice-pool/volume discipline (already deliberately mixed quiet at -13 to -17dB) to keep repeating cues subtle and non-fatiguing rather than muting them entirely |
| Flat, identical feedback intensity for every hit regardless of size | Simplicity — one damage-number style, one shake amount, one sound, for everything | This is the exact mechanism of habituation cited in game-feel literature: constant, undifferentiated feedback trains the player's brain to stop registering it within minutes, so by the time the boss fight matters the "juice" has gone stale and invisible | Scale juice magnitude to hit significance using the already-existing `from_elite`/boss distinction in the codebase, so normal hits stay light and big hits still read as big |

## Feature Dependencies

```
Damage numbers
    └──requires──> Enemy.take_damage() / Player.receive_damage() call sites (already exist)

Hit-flash + screen shake (player damage)
    └──requires──> Player.receive_damage() (already exists)
    └──enhanced-by──> notify_significant_hit()/from_elite flag (already exists) — drives magnitude scaling

Health bar flash
    └──requires──> existing `health` MultiplayerSynchronizer field (already exists, HLTH-03)

Hit-stop on kill
    └──requires──> Enemy.gd death branch (Enemy.gd:151-160)
    └──conflicts-with──> Engine.time_scale as an implementation choice (breaks host-authoritative sync) — must be local/cosmetic only

Death particle burst
    └──requires──> Enemy `died` signal / deferred queue_free (currently frees immediately — needs one-frame defer)

XP orb magnetism
    └──requires──> XpOrb.gd body_entered/collection flow (already exists, CMBT-09)
    └──enhances──> Pickup collection pop/bounce (shares floating-text/pooling infra)

XP orb travel-to-bar (delayed value update)
    └──requires──> XP orb magnetism (orb must have a "flying" state to hand off into)
    └──requires──> PlayerHUD.update_hud() decoupled from instant GameState.add_team_xp() (presentation-layer change only, no protocol change)

Level-up burst + card pop-in
    └──requires──> CardOverlay.gd (already exists, non-blocking CanvasLayer per W4)

Evolution transform closure moment
    └──requires──> Player.set_evolution_stage() RPC (already exists, Player.gd:772)
    └──enhances──> Team-wide broadcast juice pattern (reuses same "broadcast a cosmetic RPC" approach)

Ability juice (dash trail, aura pulse, heal sparkle, drone deploy)
    └──requires──> existing role ability RPCs (Tank shield_active, Speedster dash_invincible, Engineer HealDrone/passive — all already authority-gated from Phase 5)

Downed/revive juice (broadcast to all players)
    └──requires──> Player._enter_downed()/revive()/set_revive_progress() (already exist)
    └──requires──> GameEvents.player_downed / player_revived signals (ALREADY DECLARED, currently unused/unwired — GameEvents.gd:13,15)

Sound cue pairing (all events)
    └──requires──> Sfx.gd autoload (already exists — 12-voice pool, shoot()/hit() implemented; every new cue is one more method in this pattern)
    └──conflicts-with──> firing a cue on every tick of continuous effects (burn DoT, Earth heal) — pair with onset only, not every tick

Team-wide broadcast juice (healing, revival, big hits)
    └──requires──> GameEvents.gd RPC broadcast pattern (emit_hud, already implemented and provable — GameEvents.gd:21-23)
```

### Dependency Notes

- **XP travel-to-bar requires XP orb magnetism:** the "fly toward player, then fly to bar" sequence needs the orb to already be in a client-local "attracted" state before it can hand off into a second "flying to UI" state — building the bar-arrival juice without the magnetism juice first would mean re-deriving the same tween-sequencing logic twice.
- **Hit-stop conflicts with `Engine.time_scale`:** this is the single most important implementation constraint in this research. Because the game runs as separate OS processes on separate LAN laptops with host-authoritative simulation, any global time-scale manipulation either slows the shared authoritative game state for everyone (if done on host) or desyncs local rendering from synced truth (if done on a client). Hit-stop must be implemented as a scoped, cosmetic pause on specific nodes, never as an engine-wide time change.
- **Downed/revive team-visibility requires already-stubbed signals:** `GameEvents.gd` was scaffolded in Phase 1 with `player_downed`/`player_revived` signals explicitly for this purpose (see `01-01-SUMMARY.md`) but they were never wired to an emitter or listener. This milestone is the natural place to finally connect them, following the exact `emit_hud()` RPC pattern already proven in the same file.
- **Sound cue pairing conflicts with continuous-effect ticks:** Fire burn (1 dmg/sec) and Earth passive team heal (per-second tick, ELEM-05) are both already-implemented recurring effects. A literal "sound on every juice moment" reading would fire a cue every single tick for the run's duration — this needs an explicit onset-vs-tick distinction decided before implementation, not left to emerge ad hoc per weapon.
- **Comic UI styling enhances (not requires) all UI-facing juice:** damage numbers, floating pickup text, and card pop-ins are not blocked on `UiStyle.gd`/Bangers font existing, but reusing them is near-zero-cost and keeps new juice visually consistent with the recent "Comic UI Pass" commit.

## MVP Definition

This research applies to a single milestone (v1.1 Juicy Feedback) rather than a full product, so "MVP" here means the sequencing within that milestone rather than a separate future release.

### Launch With (v1.1 core)

The foundational combat-and-collection loop juice — everything else in the milestone either reuses or extends these patterns, so building them first de-risks the rest.

- [ ] Floating damage numbers (pooled) — establishes the pooling pattern reused by pickup floating text
- [ ] Player hit-flash + screen shake (capped magnitude) + health bar flash — core "ouch" feedback loop
- [ ] Hit-stop on kill (local/cosmetic, NOT `Engine.time_scale`) + death particle burst
- [ ] XP orb magnetism + travel-to-bar delayed value update — establishes the "world event → UI event" handoff pattern
- [ ] Sound cue pairing for all of the above via `Sfx.gd` extension — proves out the onset-vs-tick cue discipline early, before more event types are added

### Add After Validation (v1.1 second wave)

Builds on the foundational patterns above once they're proven not to feel noisy or laggy.

- [ ] Pickup collection pop/bounce/floating text (weapon unlocks, car-part pickups) — reuses damage-number pooling infra
- [ ] Level-up burst + card overlay pop-in
- [ ] Ability juice: dash trail, aura pulse, heal sparkle, drone deploy — reuses element-specific VFX approach
- [ ] Enemy spawn-in effect
- [ ] Downed/revive juice broadcast to all players — wires the already-stubbed `GameEvents.player_downed`/`player_revived` signals
- [ ] Evolution stage transform closure moment — highest complexity, most agency-risk, deliberately sequenced last so the "keep it short and non-blocking" discipline is already established from earlier items

### Future Consideration (beyond this milestone)

- [ ] Player-facing accessibility settings (screen-shake intensity slider/off switch, hit-flash intensity) — not required for a controlled demo but flagged given the epilepsy/motion-sickness research above; worth a lightweight version if time allows since the demo is shown to a live audience
- [ ] Per-effect "nuisance" audio budget/ducking system beyond the existing 12-voice pool — only needed if playtesting reveals the extended `Sfx.gd` cue set becomes noisy in 3-player sessions with dense enemy waves

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Floating damage numbers | HIGH | LOW | P1 |
| Hit-flash + screen shake + health bar flash | HIGH | LOW–MEDIUM | P1 |
| Hit-stop + death particle burst | HIGH | MEDIUM | P1 |
| XP orb magnetism + travel-to-bar | HIGH | MEDIUM–HIGH | P1 |
| Sound cue pairing (foundation cues) | HIGH | LOW per-cue | P1 |
| Pickup pop/bounce/floating text | MEDIUM | LOW | P2 |
| Level-up burst + card pop-in | MEDIUM | LOW–MEDIUM | P2 |
| Ability juice (dash/aura/heal/drone) | MEDIUM | MEDIUM | P2 |
| Enemy spawn-in effect | LOW–MEDIUM | LOW | P2 |
| Downed/revive team-visible juice | HIGH (explicit user requirement) | MEDIUM | P2 |
| Evolution transform closure moment | HIGH (differentiator) | MEDIUM–HIGH | P2 |
| Accessibility juice settings | LOW (demo context) / MEDIUM (goodwill) | LOW–MEDIUM | P3 |

**Priority key:**
- P1: Foundational — establishes patterns everything else reuses
- P2: Full milestone scope — builds on P1 patterns
- P3: Nice to have, only if time remains

## Competitor / Reference Title Analysis

| Feature | Vampire Survivors / Brotato (single-player bullet-heaven) | Deep Rock Galactic / Vermintide (co-op action) | Our Approach |
|---------|---|---|---|
| Damage numbers | Simple floating numbers, size-scaled by damage, high volume tolerated since it's the whole spectacle | Less central — dialogue/audio carries impact feedback more than numbers | Pooled numbers, size/color scaled by `from_elite`, capped concurrent count |
| Pickup magnetism | Core "magnet radius" stat, explicitly called out by players as one of the most satisfying mechanics in the genre | N/A (not a pickup-swarm genre) | XP orb magnetism + delayed bar-arrival, matching the user's explicit spec |
| Revive feedback | N/A (single-player, no revive) | Proximity + hold-to-revive with an audible "calling for help" cue and clearly visible downed state; the single most-cited co-op tension mechanic in these games | Reuse proximity+hold model already built (HLTH-05/06); add broadcast juice so ALL players — not just the two involved — see/hear the revive succeed, matching this project's team-visibility requirement |
| Big moment pacing | Level-up card pick pauses very briefly, no cutscene; game keeps pace deliberately fast ("almost never feel like you're waiting") | Boss/event stingers are short (a few seconds) specifically so co-op partners aren't left idle | Evolution transform capped ~1–1.5s, non-blocking, matching this "never make a teammate wait" convention |
| Over-juicing risk | Widely discussed genre criticism: excess juice can mask shallow mechanics and cause fatigue once the initial spectacle wears off | Less of an issue — co-op titles tend to keep juice functional (readability of team state) over spectacle | Intensity-scaled juice (small hit/small cue, big hit/big cue) to avoid habituation flagged in genre post-mortems |

## Sources

- [The "Juice" Problem: How Exaggerated Feedback is Harming Game Design — Wayline](https://www.wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design) — MEDIUM confidence, genre-level critique of over-juicing and agency loss
- [Is Your Game Too Thirsty? The Perils of Over-Juicing — Wayline](https://www.wayline.io/blog/the-perils-of-over-juicing) — MEDIUM confidence, corroborates habituation/fatigue risk
- [Juice Overload: When Sensory Feedback Hurts Gameplay — Wayline](https://www.wayline.io/blog/juice-overload-sensory-feedback-hurts-gameplay) — MEDIUM confidence
- [Designing Game Feel: A Survey (arXiv:2011.09201)](https://arxiv.org/pdf/2011.09201) — MEDIUM-HIGH confidence, academic survey covering hit-stop, screen shake, and impact feedback research base
- [What Features Influence Impact Feel? A Study of Impact Feedback in Action Games (arXiv:2208.06155)](https://arxiv.org/pdf/2208.06155) — MEDIUM-HIGH confidence
- [Vampire Survivors Design Analysis — Kokutech](https://www.kokutech.com/blog/gamedev/design-patterns/power-fantasy/vampire-survivors) — MEDIUM confidence, corroborates XP-gem/magnetism reward-cadence claims
- [Magnet — Vampire Survivors Wiki (Fandom)](https://vampire-survivors.fandom.com/wiki/Magnet) — HIGH confidence for mechanic description (primary wiki source)
- [Xbox Accessibility Guideline 118 — Microsoft Learn](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118) — HIGH confidence, official accessibility guidance on adjustable screen shake
- [Avoid flickering images and repetitive patterns — Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/) — HIGH confidence, industry-standard accessibility reference
- [Reviving needs a rework?! — Fatshark Forums (Vermintide/Darktide)](https://forums.fatsharkgames.com/t/reviving-needs-a-rework/74751) — LOW-MEDIUM confidence, community discussion of co-op revive feedback design
- [Health — Deep Rock Galactic Wiki](https://deeprockgalactic.fandom.com/wiki/Health) — HIGH confidence for mechanic description (primary wiki source)
- Direct codebase inspection (HIGH confidence — ground truth, not training-data assumption): `scenes/Player.gd`, `scenes/enemies/Enemy.gd`, `scenes/pickups/XpOrb.gd`, `scenes/ui/PlayerHUD.gd`, `scenes/ui/CarHUD.gd`, `scenes/ui/CardOverlay.gd`, `autoloads/GameEvents.gd`, `autoloads/Sfx.gd`, `autoloads/Music.gd`

---
*Feature research for: game-feel / juice milestone, co-op LAN action-roguelike*
*Researched: 2026-07-13*
