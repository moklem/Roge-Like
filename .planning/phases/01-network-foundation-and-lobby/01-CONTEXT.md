# Phase 1: Network Foundation & Lobby — Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a working LAN session layer: host creates a session, clients join via IP, all players select a role and element in a shared lobby screen, ready-up gates the start, and host disconnection is handled cleanly. No gameplay, no movement, no combat — just the connection infrastructure and lobby UI that every subsequent phase depends on.

</domain>

<decisions>
## Implementation Decisions

### Lobby Flow & Ready-Up

- **D-01:** Each player must explicitly press a **Ready** button before the host's Start button enables. Host can only start once all connected players are ready.
- **D-02:** Picks are **locked on Ready**. A player can un-ready at any time to change their role or element selection, then re-ready.
- **D-03:** Host sees the lobby immediately after creating a session and can start **solo** (NET-05 — 1-player mode). No separate "waiting for players" screen. Start is available as long as the host themselves is ready.
- **D-04:** Host disconnecting **at any point** (in lobby or in game) triggers auto-return to main menu on all clients after a short delay. No manual button required — automatic after ~2 seconds.

### Player Identity

- **D-05:** **Role IS the identity.** No player name entry, no generic "Player 1/2/3" labels. Players are identified throughout the session by their role name (Tank, Speedster, Engineer).
- **D-06:** A newly connected client shows as **"Player"** (placeholder) in the lobby list until they confirm a role — at which point the label instantly updates to their role name on all screens.

### Role + Element Pick UI

- **D-07:** **Single screen, two sections.** Top section = role pick (3 choices: Tank, Speedster, Engineer). Bottom section = element pick (3 choices: Fire, Ice, Earth). Both choices made on the same screen before pressing Ready. No sequential steps.
- **D-08:** A role already taken by another player is **grayed out with a "Taken" label**. Clicking it does nothing. No error message needed.
- **D-09:** A **live player list panel on the right side** of the lobby screen shows all connected players, each row displaying: placeholder/role name, element pick (if chosen), and ready status (not ready / ready). Updates in real time as players make picks.

### Network & Session

- **D-10:** Port **7000** hardcoded. No UI for port configuration — demo simplicity.
- **D-11:** `ENetMultiplayerPeer` only. No third-party networking addons.
- **D-12:** Three autoloads established in this phase: `Lobby` (connection lifecycle), `GameEvents` (signal bus — wired here even if unused until Phase 6), `GameState` (authoritative state — wired here even if unused until Phase 6). This prevents RPC signature drift issues later.
- **D-13:** Host ID is always `1` (Godot ENet convention). All host-only guards use `multiplayer.is_server()` or `get_multiplayer_authority() == 1`.

### RPC Discipline (Pitfall Prevention)

- **D-14:** All `@rpc`-annotated functions must be defined with **identical annotation and signature** on both host and client at the same NodePath. Establish this as a rule in Phase 1 before any other code exists. Any RPC violation breaks ALL RPCs in the script silently.
- **D-15:** No RPC calls in `_ready()`. All initial state broadcasts (player registry, role picks) must be sent inside `peer_connected` signal handlers, never on `_ready()`.
- **D-16:** `peer_disconnected` signal wired in `Lobby` autoload's `_ready()`. When `id == 1` (host disconnected), trigger scene change to main menu on all clients. This must be tested explicitly in this phase.

### OpenCode's Discretion

- Connection failure UX (failed join attempt) was not discussed — OpenCode decides: show an inline error label on the join screen with the error text and a Retry button. No auto-retry.
- Visual styling of the lobby (colors, fonts, layout proportions) — placeholder aesthetic using Godot's default theme is fine for this phase.
- Exact ready status indicator style (checkmark icon, colored dot, text label) — OpenCode decides.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Godot 4 Multiplayer (Technical Foundation)

- `.planning/research/STACK.md` — Full Godot 4.6.2 multiplayer stack: ENet peer setup code, `@rpc` mode table, MultiplayerSynchronizer/Spawner config, authority model. Contains exact GDScript patterns for host/client init.
- `.planning/research/ARCHITECTURE.md` — Scene tree structure, three-autoload pattern (Lobby / GameEvents / GameState), host-authoritative split table, RPC data flow for lobby events, suggested build order.
- `.planning/research/PITFALLS.md` — P1 (RPC signature mismatch), P2 (RPC before peer connected), P9 (host disconnect unhandled). All three must be addressed in Phase 1.

### Project Requirements

- `.planning/REQUIREMENTS.md` §Network (NET-01–05), §Lobby (LOBB-01–05) — the 10 requirements this phase must satisfy.
- `.planning/PROJECT.md` — Key Decisions table (host-authoritative, Driver NPC, no host migration, elements separate from role).

### Roadmap Context

- `.planning/ROADMAP.md` §Phase 1 — goal, requirements list, success criteria, pitfall watch.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- None yet — greenfield. Phase 1 establishes the foundation all subsequent phases build on.

### Established Patterns

- **Three-autoload pattern** (from ARCHITECTURE.md): `Lobby`, `GameEvents`, `GameState` as project-level singletons. All three should be registered in `project.godot` in this phase even if `GameEvents` and `GameState` have minimal logic until later phases.
- **host-authoritative**: Host peer ID is always `1`. All authority checks use `multiplayer.is_server()` or `multiplayer.get_unique_id() == 1`. Enforced from Phase 1 onward.

### Integration Points

- `Lobby` autoload is the entry point for all subsequent phases — Phase 2 (player spawning), Phase 3 (game start), Phase 6 (game over) all depend on the peer registry `Lobby.players: Dictionary` built in this phase.
- `Game.tscn` transition (host pressing Start → all clients load the game scene) is the exit condition of Phase 1 and the entry condition of Phase 2.

</code_context>

<specifics>
## Specific Ideas

- The lobby should be functional but minimal — it's a demo setup screen, not a polished product UI.
- The IP display (NET-01: host's IP shown for others to enter) should be prominent and easy to read from across a table or on a projected screen.
- Solo mode (NET-05) is primarily for developer testing. It doesn't need special UI — host just starts with 1 player in the lobby.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1 — Network Foundation & Lobby*
*Context gathered: 2026-05-05*
