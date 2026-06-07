# Game Mechanics Overview

---

## Core Loop

```
 LOBBY ──► ROOM 1 ──► ROOM 2 ──► ROOM 3 (BOSS)
             │          │              │
             └──────────┴──────────────┘
                   Kill enemies
                   Collect XP → Level Up → Pick 1 of 3 Cards
                   Pick up Car Parts → Unlock Weapons
                        ↓ Loop ends (boss killed or 15 min up)
                   Loop restarts — harder each time
```

---

## Players  `3 players · LAN co-op`

**Each player picks one Role + one Element independently**

| Role | Unique Trait | Stage 2 Ability |
|------|-------------|-----------------|
| **Tank** | Higher HP · melee aura | Burst aura (larger, timed) |
| **Speedster** | Faster movement · dash | Afterimage dash (leaves damage trail) |
| **Engineer** | Passive team heal · drone | Repair pulse (burst heal to all) |

| Element | Effect | HUD Trigger |
|---------|--------|-------------|
| 🔥 **Fire** | Burn DoT on hit + periodic ring | ENGINE OVERHEAT |
| ❄️ **Ice** | Slow on hit + slowing ground trail | AC COLD |
| 🌿 **Earth** | Passive 1 HP/s team heal + pushback | SEAT MASSAGE |

**Downed & Revive:** HP → 0 = downed · teammate holds `E` for ~3.5 s to revive (50 HP) · max **1 revive per loop** · **all down = game over**

---

## Evolution  `Car → Proto-Bot → Full AutoBot`

```
 Stage 1 [Normal Car]  ──► Stage 2 [Proto-Bot]  ──► Stage 3 [Full AutoBot]
  Base stats                New ability unlocks        All abilities active
  Car movement              Robot movement              Max stats + visuals
```

---

## Weapons  `1 starter · 5 pickups · max 6 active`

> Unlocked via **Car Part drops** (25% on kill) · all weapons **auto-aim, auto-fire**

| Weapon | Cooldown | Effect |
|--------|----------|--------|
| Screws & Bolts *(starter)* | 0.5 s | Single projectile → nearest enemy |
| Exhaust Flames | 1.5 s | 60° cone, 120 px |
| Spinning Tires | passive | 3 orbiting hitboxes |
| Antenna Beam | 2.0 s | 500 px piercing laser |
| Horn Shockwave | 3.0 s | 360° burst, ~150 px |
| Airbag Shield | passive | Absorbs 1 lethal hit |

**Level Up Cards:** On level-up → choose 1 of 3 cards: weapon unlock / weapon upgrade (lvl 1→3) / element upgrade / stat boost

---

## Rooms & Loop

```
 Room 1 · ERBA          Room 2 · Bamberg         Room 3 · Burg Altenburg
 Open arena              Narrow corridors          Boss arena
 Tutorial density        Higher density            Boss + mob swarms
```
- **15-minute shared timer** — loop ends when timer expires or boss is defeated
- Each new loop: enemy HP, damage, and density scale up · weapons & XP carry over

---

## CARIAD HUD  `always-visible side panel`

```
 ┌──────────────────────────┐
 │ AC ❄️  COLD               │  ← Ice ability used
 │ ENGINE 🔥  OVERHEAT       │  ← Fire ability used
 │ SEAT MASSAGE 🌿  ACTIVE   │  ← Earth healing
 │ SUSPENSION ⚡  IMPACT     │  ← Player hit hard
 │ LIDAR 🔴  OBJ DETECTED   │  ← Enemy spawns
 │ V2X 📡  SIGNAL SENT       │  ← Periodic auto-trigger
 └──────────────────────────┘
```
Events broadcast to **all screens simultaneously** · each indicator fades after ~3 s
