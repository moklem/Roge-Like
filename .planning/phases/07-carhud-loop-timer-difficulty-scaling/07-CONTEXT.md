# Phase 7: CarHUD, Loop Timer & Difficulty Scaling - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the CARIAD car HUD side panel — a single shared dashboard visible to all players simultaneously that lights up 5 named indicators (AC, ENGINE, SEAT MASSAGE, SUSPENSION, LIDAR) on game events via RPC broadcast. Add a "Loop: N" display showing the current loop number. Implement per-loop difficulty scaling (enemy HP, damage, spawn density, and XP gain). Wire the revive-once-per-loop limit (HLTH-07). Add a new elite enemy type that triggers the LIDAR indicator when it spawns.

**Not in Phase 7 scope:**
- Actual loop transition (boss defeat → next loop) — Phase 8 wires that when boss room exists
- V2X indicator — removed from scope
- Visible 15-minute countdown timer — LOOP-01 removed; 15 minutes is a design target only
- Rooms 2 & 3 — Phase 8

</domain>

<decisions>
## Implementation Decisions

### CarHUD Panel (HUD-01–09)

- **D-01:** CarHUD is a **single global CanvasLayer** added as a child of Game.tscn — not per-player. One panel for all clients. Represents the NPC driver's vehicle dashboard that all players can see simultaneously.
- **D-02:** Panel positioned as a **right-side vertical strip**, anchored to the right edge of the viewport. Game viewport and gameplay stay on the left. This is a new `CarHUD.tscn` scene instantiated in Game.tscn at startup.
- **D-03:** **5 active indicators** (V2X removed): AC ❄️ COLD, ENGINE 🔥 OVERHEAT, SEAT MASSAGE 🌿 ACTIVE, SUSPENSION ⚡ IMPACT, LIDAR 🔴 OBJECT DETECTED.
- **D-04:** Indicator visual states:
  - **Idle:** Dark/grey `StyleBoxFlat` background, dim label text
  - **Active:** Bright `StyleBoxFlat` background color per indicator — AC = blue, ENGINE = red, SEAT MASSAGE = green, SUSPENSION = yellow, LIDAR = red/orange
  - Labels include emoji exactly as in requirements
- **D-05:** Each indicator holds lit for **2 seconds** then fades out over **0.5 seconds** (using a Tween, same pattern as existing text label in Game.gd). Each indicator manages its own tween independently.
- **D-06:** **Loop number display** on the CarHUD panel: a "Loop: N" label at the top (or bottom) of the side panel. Reads from `GameState.loop_number`, updated when loop number changes.

### RPC Broadcast (HUD-10)

- **D-07:** `GameEvents.emit_hud(event_name: String)` becomes `@rpc("authority", "call_local", "reliable")`. Host calls it → all peers receive the signal → their local CarHUD panel lights up the matching indicator. This converts the existing local signal into a network-synced call.
- **D-08:** All existing callers that call `GameEvents.emit_hud("...")` on the host (in `Game.gd`, `Player.gd` element procs) are already host-guarded — they work without change. The RPC annotation on `emit_hud` itself handles broadcast.

### HUD Trigger Thresholds

- **D-09:** **SUSPENSION (HUD-06):** Fires when any player takes **15 or more damage in a single hit**. Checked in `Player.receive_damage()` after the damage amount is calculated. Host-only emit: `if multiplayer.is_server() and damage >= 15: GameEvents.emit_hud.rpc("suspension")`.
- **D-10:** **LIDAR (HUD-07):** Fires only when an **elite enemy spawns** — not for normal enemy spawns. Elite enemies are a new second enemy type added in Phase 7.
- **D-11:** **V2X (HUD-08):** Removed from Phase 7 scope entirely.

### Elite Enemy (new in Phase 7)

- **D-12:** A second enemy variant — **elite enemy** — is added in Phase 7. Characteristics: larger visual size, **2× base HP** (relative to normal enemy), **1.5× base damage**, spawns at **low random frequency** (not on every kill replacement — spawned separately by the host on a timer).
- **D-13:** Elite enemy spawn trigger: host timer fires every **45–90 seconds** (random interval). One elite spawns per trigger at a random spawn point. This triggers `GameEvents.emit_hud("lidar")`.
- **D-14:** Elite enemy is a separate scene (`EliteEnemy.tscn`) or reuses `Enemy.tscn` with different stats passed via spawn data — planner decides based on how Enemy.gd is structured. Must be pre-registered in `EnemySpawner` spawnable list (P7 pattern).

### Loop Infrastructure (LOOP-01–06)

- **D-15:** **No visible countdown timer.** LOOP-01 is removed. The "15-minute loop" is a design target for how long Room 1 → 2 → 3 → Boss should take, not a hard mechanical timer.
- **D-16:** **Loop number** (`GameState.loop_number`) is initialized to 1 at game start. It is displayed as "Loop: N" on the CarHUD panel.
- **D-17:** Phase 7 provides **hook points** for Phase 8 to call: `GameState.start_next_loop()` — increments `loop_number`, resets `revives_used`, applies difficulty multipliers, and fires whatever reset/respawn logic Phase 8 needs. Phase 8 calls this after boss defeat.
- **D-18:** LOOP-06 (weapons, XP, evolution carry over between rooms within a session; reset only on full death) is already handled by the existing `_broadcast_game_over` reset path — no new logic needed in Phase 7.

### Difficulty Scaling (LOOP-04)

- **D-19:** Each loop, enemies scale as follows (multiplied from base values, per `loop_number`):
  - **HP:** base HP × `1.0 + (loop_number - 1) × 0.25` (loop 1 = ×1.0, loop 2 = ×1.25, loop 3 = ×1.5)
  - **Damage:** same multiplier as HP
  - **Initial spawn count:** `INITIAL_ENEMY_COUNT × 1.5^(loop_number - 1)`, rounded. Loop 1: 8, loop 2: 12, loop 3: 18.
  - **XP per orb:** `5 × (1.0 + (loop_number - 1) × 0.25)`. Loop 1: 5 XP, loop 2: 6.25 XP (round to 6), loop 3: 7.5 XP (round to 8).
- **D-20:** Scaling is **applied at spawn time** — when `_do_spawn_enemy()` runs, it reads `GameState.loop_number` and adjusts the enemy's stats in `_ready()` or via spawn data. Existing enemies are not retroactively scaled mid-loop.
- **D-21:** Difficulty multipliers are **computed from `GameState.loop_number`** — no stored multiplier vars needed. Pure formula.

### Revive Limit Per Loop (HLTH-07)

- **D-22:** `GameState.revives_used: Dictionary` already exists (peer_id → int count). Phase 7 wires it:
  - **Block:** In `Game.gd attempt_revive()`, before revive completes: check `GameState.revives_used.get(target_id, 0) >= 1` → if true, cancel revive silently (target stays downed).
  - **Track:** After `target.receive_revive.rpc_id(target.peer_id)` succeeds, increment `GameState.revives_used[target_id]`.
  - **Reset:** `GameState.start_next_loop()` clears `revives_used = {}`.

### Claude's Discretion

- Elite enemy exact visual (suggest larger ColorRect, distinct color — dark red or purple — to visually distinguish from normal enemies)
- Elite enemy exact base stats (suggest 40 HP base vs 20 for normal; planner tunes from there)
- Elite enemy spawn timer exact randomization (45–90s is the range; planner implements with randf_range)
- Whether elite enemy drops a car-part pickup at higher rate than normal enemies
- CarHUD panel exact dimensions (suggest 200px wide, full viewport height)
- Loop: N label position within the panel (top or bottom of the indicator list)
- Whether LIDAR indicator uses same fade pattern as other indicators or stays lit longer given it's a "detected object"

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Architecture

- `.planning/phases/01-network-foundation-and-lobby/01-CONTEXT.md` — Three-autoload pattern (Lobby/GameEvents/GameState), RPC discipline rules
- `.planning/phases/05-roles-elements/05-CONTEXT.md` — Element → HUD event name mappings (D-ELEM-07): fire→"engine", ice→"ac", earth→"seat_massage"
- `.planning/phases/06-xp-level-up-cards-and-evolution/06-CONTEXT.md` — CanvasLayer pattern for local UI (W4), host-authoritative state, `_broadcast_game_over` reset path, `is_picking_card` guard

### Live Code (read before modifying)

- `autoloads/GameEvents.gd` — `emit_hud(event_name)` currently a local signal only; Phase 7 adds `@rpc("authority", "call_local", "reliable")` annotation. `hud_event` signal already declared. `loop_ended` signal stub already there.
- `autoloads/GameState.gd` — `loop_timer` (unused in Phase 7), `loop_number: int = 0`, `revives_used: Dictionary` all already exist. Phase 7 initializes `loop_number = 1` at game start and adds `start_next_loop()` method.
- `scenes/Game.gd` — `_on_hud_event()` currently handles HUD events as a text label (lines 109–121); Phase 7 replaces this with CarHUD scene delegation. `attempt_revive()` gets `revives_used` check wired in. `_on_enemy_died()` gets elite enemy spawn logic.
- `scenes/enemies/Enemy.gd` — base HP, damage, speed values; Phase 7 reads these as base stats for elite enemy variant. `receive_damage` / `died` signal pattern reused for elite.
- `scenes/ui/PlayerHUD.gd` — bottom CanvasLayer on Player node; **does not** receive CarHUD content. These are separate: PlayerHUD = per-player XP/Level/Stage strip; CarHUD = global dashboard.

### Project Requirements

- `.planning/ROADMAP.md` §Phase 7 — HUD-01–10, LOOP-01–06, HLTH-07 (17 requirements total; LOOP-01/V2X removed per discussion)
- `.planning/PROJECT.md` — "The CARIAD HUD must always fire convincingly — every major game event should trigger the corresponding vehicle sensor indicator" — core value statement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`GameEvents.emit_hud()` + `hud_event` signal** — Signal bus is already wired in `Game.gd` (`GameEvents.hud_event.connect(_on_hud_event)` line 106). Phase 7 adds the `@rpc` annotation and builds the CarHUD panel that listens to the signal. The existing text-label handler (`_on_hud_event` lines 109–121) is replaced by CarHUD's handler.
- **`Game.gd._show_earth_shockwave` tween pattern** — ColorRect with tween fade-out (lines 617–631) is the model for CarHUD indicator fade animation. Same tween approach: `tween_property(node, "modulate:a", 0.0, 0.5)`.
- **`Game.gd._on_enemy_died()` spawn path** — Elite enemy spawn will add a separate timer-triggered path (not on kill), but the `$EnemySpawner.spawn.call_deferred({...})` pattern is identical.
- **`GameState.revives_used` dict** — Already declared and reset in `_broadcast_game_over`. Phase 7 adds the read-check and write-increment in `attempt_revive()`.
- **`attempt_revive()` revive logic** — Lines 273–312 in Game.gd. The revive block check inserts before `target.receive_revive.rpc_id(target.peer_id)` on line 312.

### Established Patterns

- **Host-authoritative HUD emit:** All `GameEvents.emit_hud()` calls are already guarded with `if multiplayer.is_server():`. Adding `@rpc("authority", "call_local", "reliable")` to `emit_hud` means host calls it → all peers' `hud_event` signal fires → their local CarHUD lights up. No call-site changes needed.
- **CanvasLayer for persistent UI:** CarHUD is a CanvasLayer (like PlayerHUD) — always on top, not clipped by viewport. Added to Game.tscn rather than Player.tscn because it's shared.
- **P7 spawnable list pre-registration:** EliteEnemy scene must be pre-registered in `$EnemySpawner.add_spawnable_scene(...)` before any elite spawns are triggered.
- **`call_deferred` for physics-safe spawns:** Elite enemy timer-triggered spawn uses `call_deferred(...)` if triggered from `_process`.

### Integration Points

- **`GameEvents.gd`:** Add `@rpc("authority", "call_local", "reliable")` to `emit_hud`. No other changes — callers work as-is.
- **`GameState.gd`:** Initialize `loop_number = 1` in `_ready()`. Add `start_next_loop()` method: increment loop_number, reset revives_used, log to console. Phase 8 calls this on boss defeat.
- **`Game.gd`:** (1) Instantiate CarHUD.tscn in `_ready()` and add to HUD CanvasLayer. (2) Remove old `_setup_player_hud()` text-label HUD handler or repurpose it without HUD event text. (3) Add elite enemy spawn timer. (4) Wire revives_used check in `attempt_revive()`. (5) Wire SUSPENSION emit in player damage path (or in `attempt_revive` receipt — actually in Player.gd).
- **`Player.gd` `receive_damage()`:** After calculating final damage: `if multiplayer.is_server() and damage >= 15: GameEvents.emit_hud.rpc("suspension")`.
- **New: `scenes/ui/CarHUD.tscn` + `CarHUD.gd`:** New scene. CanvasLayer with VBoxContainer of 5 indicator boxes (PanelContainer + Label each) + loop number label. Each indicator has `activate()` method that sets bright color + starts fade tween. Connects to `GameEvents.hud_event` signal in `_ready()`.
- **New: `scenes/enemies/EliteEnemy.tscn` + `EliteEnemy.gd`** (or reuse Enemy.tscn with a data flag): Larger visual, 2× HP, 1.5× damage, connects `died` to same `_on_enemy_died` handler. Pre-registered in EnemySpawner.

</code_context>

<specifics>
## Specific Ideas

- **CarHUD indicator activation flow:** `CarHUD._on_hud_event(event_name)` matches event_name → calls `_indicators[event_name].activate()`. Each indicator node has `activate()`: set `stylebox.bg_color = lit_color`, start tween that waits 2s then fades `modulate.a` to 0 over 0.5s, then restores original style.
- **Loop number display:** A `Label` at top of CarHUD panel showing "Loop: N". Updated by `CarHUD._ready()` connecting to `GameState`'s `loop_number` — either via signal or polling in `_process()`.
- **SUSPENSION trigger site:** In `Player.gd receive_damage()`, after all reductions (shield, invincibility) are applied and before updating health: `var final_dmg := ...; if multiplayer.is_server() and final_dmg >= 15: GameEvents.emit_hud.rpc("suspension")`.
- **Elite enemy spawn timer:** A `Timer` node in Game.tscn (or a float accumulator in `_process`) that fires every `randf_range(45.0, 90.0)` seconds. On fire: `$EnemySpawner.spawn.call_deferred({"type": "elite", "pos": random_spawn_point})`. `_do_spawn_enemy` matches `type == "elite"` and instantiates EliteEnemy instead of Enemy.
- **Difficulty scaling apply-at-spawn:** In `_do_spawn_enemy()`, after instantiation: `var mult := 1.0 + (GameState.loop_number - 1) * 0.25; e.MAX_HP = int(e.MAX_HP * mult); e.health = e.MAX_HP; e.damage = int(e.damage * mult)`. Assumes Enemy.gd exposes `damage` as a var.
- **XP scaling:** In `XpOrb.gd _request_collect()`, compute XP: `var xp_amount := roundi(5.0 * (1.0 + (GameState.loop_number - 1) * 0.25))` instead of hardcoded 5.

</specifics>

<deferred>
## Deferred Ideas

- **V2X auto-trigger indicator** — Removed from Phase 7 scope by user decision. If added in a future phase, implement as a host timer (30–60s random interval) calling `GameEvents.emit_hud.rpc("v2x")`.
- **Visible 15-minute countdown timer (LOOP-01)** — Removed by user decision. 15 minutes is a design target for loop length, not a visible UI element.
- **LIDAR for all enemy spawns** — Only elite enemy spawns trigger LIDAR. Normal enemy replacement spawns do not. Future phase could add LIDAR for mob swarms during boss fight (ROOM-06 already requires this in Phase 8).
- **Cooldown reduction stat boost (Game.gd line 432)** — Already noted as `# TODO Phase 7` in code but not discussed. Planner should evaluate whether weapon cooldown reduction is wired in Phase 7 or deferred to Phase 8.

</deferred>

---

*Phase: 7-carhud-loop-timer-difficulty-scaling*
*Context gathered: 2026-06-19*
