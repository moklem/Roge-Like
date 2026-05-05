# Phase 1: Network Foundation & Lobby — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-05
**Phase:** 1 — Network Foundation & Lobby
**Areas discussed:** Lobby flow & ready-up, Player identity in session, Role+element pick UI

---

## Lobby Flow & Ready-Up

### Q1 — Does each player need to confirm ready, or does host just start?

| Option | Description | Selected |
|--------|-------------|----------|
| All players ready-up | Each player manually clicks Ready; host Start only enables when all ready | ✓ |
| Host starts whenever | Host can start at any time once at least 1 player is present | |
| Auto-start on all confirmed | No Ready button — auto-starts after everyone confirms role + element | |

**Notes:** Prevents host from starting before others have had a chance to pick their role and element.

---

### Q2 — Can players change their role/element selection after picking it?

| Option | Description | Selected |
|--------|-------------|----------|
| Locked on Ready, un-ready to change | Picks locked on Ready; player can un-ready to change, then re-ready | ✓ |
| Immediate lock on pick, change until start | Role locks for others immediately; own pick changeable until start | |
| Everything unlocked until Start | Anyone can change anything until host presses Start | |

---

### Q3 — What does the host see immediately after creating a session before anyone joins?

| Option | Description | Selected |
|--------|-------------|----------|
| Host waits alone, Start disabled | Lobby visible; Start disabled until ≥1 more player joins | |
| Pre-lobby waiting screen | Separate waiting state before lobby opens | |
| Solo start available immediately | Host can start solo right away — 1-player mode proceeds immediately | ✓ |

**Notes:** Supports NET-05 (solo testable) directly — no artificial blocking of 1-player use.

---

### Q4 — When host disconnects mid-lobby, what do clients see?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-return to main menu | "Host Left" screen then automatic return after short delay | ✓ |
| Manual return, button to go back | "Host Left" screen requiring manual button press | |

---

## Player Identity in Session

### Q1 — How are players identified?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-numbered | Player 1, Player 2, Player 3 — host always Player 1 | |
| Optional name entry | Name typed before hosting/joining; displayed above character | |
| Role IS the identity | Identity comes from chosen role name; no generic number shown | ✓ |

---

### Q2 — What shows for a newly connected player before they pick a role?

| Option | Description | Selected |
|--------|-------------|----------|
| Anonymous until role picked | Shows "Joining..." with spinner until role confirmed | |
| Placeholder name, updates on pick | Shows "Player" immediately on join; updates to role name on pick | ✓ |

---

## Role + Element Pick UI

### Q1 — How are role and element presented for selection?

| Option | Description | Selected |
|--------|-------------|----------|
| Single screen, two sections | Top = role (3 choices), bottom = element (3 choices); pick both before Ready | ✓ |
| Sequential: role then element | Role pick first, then element appears after confirming role | |
| Two separate screens | Role screen → Next → Element screen → Ready | |

---

### Q2 — How does a taken role appear to another player?

| Option | Description | Selected |
|--------|-------------|----------|
| Grayed out with "Taken" label | Role grayed out with label showing it's taken; clicking does nothing | ✓ |
| Disappears from list | Taken role removed from list entirely | |
| Clickable with error message | Still shown and clickable; shows "Already taken" message on click | |

---

### Q3 — How do all players see each other's selections in real time (LOBB-04)?

| Option | Description | Selected |
|--------|-------------|----------|
| Live player list panel on the side | Right-side panel: each player row shows role, element, ready status; updates live | ✓ |
| Shared inline view | Each player's picks shown inline on the same screen sections | |
| Bottom summary bar | Summary bar at the bottom showing all confirmed picks | |

---

## OpenCode's Discretion

- **Connection failure UX**: Not discussed. OpenCode decides: inline error label on join screen + Retry button. No auto-retry.
- **Visual styling**: Placeholder aesthetic, default Godot theme acceptable for this phase.
- **Ready status indicator style**: Checkmark, colored dot, or text label — OpenCode decides.

## Deferred Ideas

None — discussion stayed within Phase 1 scope.
