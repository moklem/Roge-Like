# Phase 5: Roles & Elements - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-15
**Phase:** 5-roles-elements
**Areas discussed:** Ability-Tasten, Revive-Taste, Stage-2-Strategie, Element-Trefferlogik, Drohnen-Mechanik, Tank-Rolle, Speedster-Rolle, Engineer-Rolle

---

## Ability-Tasten & Revive-Taste

| Option | Description | Selected |
|--------|-------------|----------|
| E bleibt Revive, R = Rolle, F = Element | Klare Trennung; E im Projekt verdrahtet | |
| R = Revive, Q = Rollenabilty, E = Elementabilty | Revive auf R, Abilities auf Q und E | |
| E bleibt Revive, Q = alle Abilities | Eine Taste für alles | |
| R = Revive, Space = Rollenabilty, Elemente passiv | Vorgeschlagen vom User im Freitext | ✓ |

**User's choice:** R für Revive, Space für Rollenabilty, Elemente sind rein passiv (kein Ability-Key)
**Notes:** User fragte zuerst nach Übersicht aller zu belegenden Tasten. Nach der Übersicht: E war für Revive — User entschied aktiv, Revive auf R zu verlegen. Elements sind komplett passive Buffs — keine Taste nötig.

---

## Stage-2-Strategie

| Option | Description | Selected |
|--------|-------------|----------|
| Gate-Flag jetzt einbauen, immer false | evolution_stage in Player.gd; Phase 6 setzt ihn | ✓ |
| Debug-Flag: Stage-2 sofort aktiv | Wie DEBUG_WEAPON_TEST in WeaponManager | |
| Stage-2 komplett in Phase 6 verschieben | Phase 5 nur Stage-1 | |

**User's choice:** Gate-Flag jetzt einbauen (evolution_stage = 1 in Player.gd)
**Notes:** Folgeentscheidung — evolution_stage in Player.gd (nicht GameState.gd) nach kompakter Erklärung beider Optionen. User wählte die empfohlene Option.

---

## Element-Trefferlogik

| Option | Description | Selected |
|--------|-------------|----------|
| Nur Waffenprojektile | Burn/Slow bei jedem Projektiltreffer | |
| Nur ScrewsAndBolts, 25% Proc | Nur Standard-Auto-Attack, random chance | ✓ |
| Alle Schadensquellen | Projektile + Kontakt triggern Element | |

**User's choice:** Nur ScrewsAndBolts, 25% Proc-Chance
**Notes:** User spezifizierte im Freitext: "nur die Screws also der Standard-Autoattack und davon nicht jedes Projektil sondern nur random Prozentzahl davon."

**ELEM-02 Redesign (aus Diskussion):**
| Option | Description | Selected |
|--------|-------------|----------|
| Periodischer Area-Ring (Original ROADMAP) | Alle paar Sek Damage-Ring um Spieler | |
| Feuer-Burst auf nächsten Feind (Freitext) | 3-5 Projektile Richtung nächster Feind, 100% Burn | ✓ |

**Notes:** User wollte ELEM-02 vereinfachen. Wahl: 3-5 Feuer-Projektile in Richtung nächster Feind, 100% Burn-Proc, Feuer-Optik (orange Modulate).

**Ice Trail (ELEM-04):**
| Option | Description | Selected |
|--------|-------------|----------|
| Spur hinter dem Spieler (Bewegung) | Frost-Zone entlang Bewegungspfad | ✓ |
| Periodische Eiszonen (timer-basiert) | Wie Fire-Ring aber Slow | |

---

## Tank-Rolle

| Option | Description | Selected |
|--------|-------------|----------|
| 150 HP (+50%) | Spürbar, kontrollierbar | ✓ |
| 200 HP (2x) | Sehr tanky | |
| Claude entscheidet (125–175) | Tuning-Sache | |

**Tank Stage-1 Ability:**
| Option | Description | Selected |
|--------|-------------|----------|
| Kurzer Damage-Burst (Original ROLE-02) | Area2D Pulse, 1 Frame | |
| Toggle-Aura | Dauernd aktiv, an/aus | |
| 3-Sek Vollschild (Freitext) | Blockt alle Trefferpunkte, kein Schaden | ✓ |

**Notes:** User redesignte ROLE-02 aktiv. Original war "melee aura that damages nearby enemies" — User wollte stattdessen ein Schutzschild ("Schild für paar Sekunden das balanced ist und Schaden blockt"). 3 Sekunden, Vollblock, 8-Sek-Cooldown.

**Tank Stage-2:**
| Option | Description | Selected |
|--------|-------------|----------|
| Längeres Schild + Schadensreflexion | 6 Sek, reflektiert 50% zurück | ✓ |
| Bleibt der Aura-Burst (Original) | Stage-1 defensiv, Stage-2 offensiv | |
| Claude entscheidet | | |

---

## Speedster-Rolle

| Option | Description | Selected |
|--------|-------------|----------|
| 280 Speed (+40%) | Spürbar, kontrollierbar | ✓ |
| 300 Speed (+50%) | Sehr flink | |

**Speedster Stage-1 Dash:**
| Option | Description | Selected |
|--------|-------------|----------|
| Geschwindigkeits-Burst (0.3 Sek, iFrames) | Standard-Dash-Feel | ✓ |
| Teleport 200px in Bewegungsrichtung | Sofortige Neupositionierung | |

**Speedster Stage-2:**
| Option | Description | Selected |
|--------|-------------|----------|
| 1 — Afterimage-Spur | Kopien entlang Pfad, Schaden | |
| 3 — Durch-Feind-Dash | Sword-Strich-Feel | |
| 5 — Doppel-Dash | Nur Mobilität | |
| Doppel-Dash + cooler 2. Dash (Freitext) | User wollte 5 Ideen dann wählen | ✓ |

**Notes:** User wollte zunächst 5 Ideen sehen bevor Auswahl. Wählte Doppel-Dash, bat darum den 2. Dash "noch cool iwie" zu machen. Claude schlug Schockwellen-Landung beim 2. Dash vor — User stimmte zu.

Finale Stage-2: 1. Dash normal (wie Stage-1), 2. Dash innerhalb 0.8 Sek + Schockwellen-Landung (~80px Radius, ~25 Schaden, Knockback).

---

## Engineer-Rolle

| Option | Description | Selected |
|--------|-------------|----------|
| Alle 5 Sek +10 HP, 200px Radius | Proximity-basiert | ✓ |
| Alle 3 Sek +5 HP, unbegrenzte Reichweite | Häufiger, schwächer, freier | |

**Engineer Drohne (ROLE-08 — redesigned):**
| Option | Description | Selected |
|--------|-------------|----------|
| Persistenter Begleiter (folgt immer) | Immer aktiv, greift an | |
| Deployable, bleibt an Ort, schießt Screws | Erste Entscheidung | (geändert) |
| Heal-Drohne statt Angriffs-Drohne (Freitext) | User wollte Heal-Drohne | ✓ |

**Notes:** User änderte die Drohnen-Konzeption zweimal. Erste Frage: deployable, schießt Screws. Zweite Runde: User sagte "role 8 soll healen und dann darauf aufbauen" — komplette Umgestaltung zu Heal-Drohne.

**Engineer Stage-2 (ROLE-09):**
| Option | Description | Selected |
|--------|-------------|----------|
| Stage-2 Drohne: größerer Burst, mehr Heal | Gleiche Mechanik, stärkere Stats | |
| Stage-2: Repair Pulse als Extra-Ability | Manueller Burst-Heal zusätzlich | |
| Stage-2 Drohne folgt Engineer (Freitext) | Minimal größerer Radius, mehr Heal | ✓ |

**Notes:** User wollte, dass Stage-2-Drohne dem Engineer folgt (statt fester Position) und minimal stärker ist. Kein komplett neues Ability-Konzept.

---

## Claude's Discretion

- Exakter Tank-Schadensreflexions-Wert (Ausgangspunkt: 50% des geblokkten Schadens, Min 5)
- Exakter Cooldown für Fire-Burst-Timer (Ausgangspunkt: 4 Sekunden)
- Burn/Slow-Visuals auf Feinden (Color Modulate: orange für Burn, blau für Slow)
- Ice-Trail-Zone-Visual (kleines light-blue Area2D ColorRect, semi-transparent)
- Drohnen-Visual (kleiner farbiger Kreis, unterscheidbar von SpinningTires)
- Speedster-Schockwellen-Visual (kurze gelbe Ring-Expansion am Dash-Landepunkt)

## Deferred Ideas

- Elementale Kombo-Interaktionen (Fire + Ice = Steam) — explizit Out of Scope per PROJECT.md, v2
- Visuelle Differenzierung der Rollen über Farbe hinaus — Placeholder-Art für diesen Build
- Tank-Schild reflektiert AOE-Schaden — nur Direkttreffer in Phase 5
- Mehrere Engineer-Drohnen gleichzeitig — Phase 6 Upgrade-Karten-Scope
