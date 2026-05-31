# Phase 4: Weapons & Item Pickups — Discussion Log

**Date:** 2026-05-31
**Phase:** 4 — Weapons & Item Pickups
**Method:** Interactive gray-area discussion (4 areas)

---

## Areas Discussed

### 1. Weapon Upgrade-Pfad

**Question:** Sollen Upgrades (Level 1→2→3) schon in Phase 4 implementiert werden, oder erst in Phase 6?

**Options presented:**
1. Nur Unlock in Phase 4 (Recommended)
2. Doppelt-Pickup = Upgrade
3. Vollständiges Levelsystem als Stub

**User selected:** Nur Unlock in Phase 4

**Decision captured:** Phase 4 = only weapon unlock. WeaponManager stores level per weapon (starts at 1) but actual upgrades via card picks come in Phase 6.

---

### 2. Waffen-Behaviour-Tiefe

**Question:** Wie tief sollen die 5 Waffen-Mechaniken implementiert werden?

**Options presented:**
1. Echte Mechaniken (Full)
2. Korrekte Mechaniken, Simple Visuals (Recommended)
3. Alle als Projektil-Wrapper (Minimal)

**User selected:** Korrekte Mechaniken, Simple Visuals

**Sub-decisions:**

**Exhaust Flames direction:**
- Options: Bewegungsrichtung-invertiert / Zum nächsten Feind gerichtet / Asymmetrische Aura
- **Selected:** Zum nächsten Feind gerichtet

**Spinning Tires behavior:**
- Options: 3 dauerhaft orbiting Shapes / Spiralprojektile / Knockback-Shields
- **Selected:** 3 dauerhaft orbiting Shapes

**Airbag Shield mechanic:**
- Options: Auto-Cooldown Invincibility / Shield-HP-Pool mit Reload / Einmal-Charge
- **User's words:** "Er rettet dich vor dem Tod den hit der dich töten würde und danach muss wieder gefunden oder gekauft werden"
- **Decision captured:** 1 death-prevention charge. Absorbs the lethal hit. Consumed after use. Must find another pickup.

---

### 3. WeaponManager-Architektur

**Question:** Wo lebt der WeaponManager?

**Options presented:**
1. WeaponManager als Child des Players (Recommended)
2. Zentral-Autoload
3. Alles in Player.gd

**User selected:** WeaponManager als Child des Players

**Sub-decision — Spinning Tires multiplayer collisions:**
- Options: Immer aktiv, Host erkennt Damage / Nur auf Host aktiv
- **Selected:** Immer aktiv, Host erkennt Damage

---

### 4. Pickup-Drop-Logik

**User clarification needed:** Asked "was macht ein cartpart nochmal" — clarified that Car-Part pickup = item that unlocks a weapon.

**Question:** Wie oft droppen Feinde eine Car-Part?

**Options presented:**
1. 25% Zufall (Recommended)
2. Guaranteed jeder 4. Kill
3. 10%, priorisiert Neue Parts

**User selected:** 25% Zufall

**Decision captured:** 25% random drop chance per enemy death. Which of the 5 parts drops = uniformly random.

---

## OpenCode's Discretion

- Exact damage values per weapon (tunable starting points provided)
- Exact cooldown values (starting points provided in D-09—D-12)
- CarPartPickup visual shape/color per weapon type
- Antenna Beam: RayCast2D vs. long Area2D (implementation choice)

---

## Deferred Ideas

- Weapon upgrades (Level 2/3) → Phase 6 card picks
- Per-weapon visual differentiation → v2 polish
- Weapon combo interactions → future scope
