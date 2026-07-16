# Audio-Teile-Checkliste (Team-Handoff)

Jeder Trigger-Punkt im Spiel ist **fertig verdrahtet**. Es fehlen nur noch die Sound-Dateien.

**So funktioniert's:** Legt eine Datei unter dem exakten Pfad ab, der unten steht — fertig, der
Cue spielt. Kein Code-Change nötig. Solange eine Datei fehlt, ist der Cue einfach still
(`ResourceLoader.exists()`-Check in `autoloads/Sfx.gd`), nichts crasht. Ihr könnt also in
beliebiger Reihenfolge liefern und einzeln nachziehen.

👉 **Wie die Sounds klingen sollen, steht in [`AUDIO_PROMPTS.md`](./AUDIO_PROMPTS.md)** — dort gibt es
pro Cue einen fertigen, copy-paste-baren Prompt (für AI-Generatoren oder als Briefing für Sound-
Designer), plus Länge und die Fallstricke. Diese Datei hier ist die Übersicht: *was* fehlt und *wohin*.

- **Format:** `.wav` (Godot importiert das ohne Zusatzschritt)
- **Länge:** SFX kurz halten (~0.1–0.6 s). Nur die Stinger dürfen länger sein.
- **Lautstärke:** egal — die Pegel sind pro Cue im Code gesetzt (`CUES` in `autoloads/Sfx.gd`)
  und sind bewusst leise gemischt. Liefert die Samples normalisiert, wir ziehen im Code runter.

**Stand:** 21 von 34 Dateien vorhanden — der komplette Kampf-, UI- und Stinger-Kern ist da
(inkl. `game_over.wav` und zwei `xp_arrive`-Varianten). **13 fehlen**, alle in den Tabellen
unten ohne ✅: die 5 Waffen-/Rollen-Cues (`airbag_*`, `dash_shockwave`, `shield_up`,
`earth_shockwave`), `engineer_heal`, `drone_deploy`, `lidar_blip`, `exit_open`,
`boss_death`, `big_hit` und die 2 Musik-Stings. (Die 3 elementaren HUD-Echos wurden am
2026-07-16 gestrichen.)

**Varianten:** Ein Cue darf mehrere Dateien haben — einfach mehrere liefern, der Code spielt
pro Abspielvorgang zufällig eine davon (`xp_arrive.wav` + `xp_arrive_2.wav` machen es vor).
Gut gegen Abnutzung bei häufigen Cues.

---

## Stimmen-Pool & Priorität

Es gibt zwei getrennte Pools. Der geteilte Pool (16 Stimmen) trägt die Routine-Cues — bei
dichtem Beschuss schneiden die sich gegenseitig ab, das ist so gewollt, das ist Textur. Die
9 **Priority-Stinger** haben 4 eigene, reservierte Stimmen, damit ein Kill-Fanfare oder ein
Downed-Alarm nie von 20 Treffer-Ticks weggedrängt wird. Das passiert automatisch anhand der
`PRIORITY`-Liste im Code — ihr müsst dafür nichts tun.

---

## 1. Kampf (Routine)

| Cue | Datei (`res://assets/audio/sfx/…`) | Wann | Klang-Richtung |
|-----|-----------------------------------|------|----------------|
| shoot | `shoot.wav` ✅ vorhanden | Screws/Bolts feuern | metallisches "pew" |
| hit | `hit.mp3` ✅ vorhanden | Gegner nimmt Schaden | subtiler Tick |
| enemy_die | `enemy_die.wav` ✅ vorhanden | normaler Gegner stirbt | Schrott-Knirschen |

## 2. Waffen

Alle Waffen sind CARIAD-Autoteile — das darf man hören (Auspuff, Hupe, Antenne, Airbag).

| Cue | Datei | Wann | Klang-Richtung |
|-----|-------|------|----------------|
| exhaust_flames | `exhaust_flames.wav` ✅ vorhanden | Exhaust Flames feuert | Feuer-Whoosh aus dem Auspuff |
| antenna_beam | `antenna_beam.wav` ✅ vorhanden | Antenna Beam feuert | elektronischer Zap |
| horn_shockwave | `horn_shockwave.wav` ✅ vorhanden | Horn Shockwave feuert | Autohupe |
| airbag_arm | `airbag_arm.wav` | Airbag wird freigeschaltet | Aufblas-Plopp |
| airbag_break | `airbag_break.wav` | Airbag fängt tödlichen Treffer ab | Platzen / Luft ablassen |

*Spinning Tires kriegt bewusst keinen eigenen Cue — die Waffe tickt über den geteilten
`hit`-Cue (alle 0.5 s pro Gegner), ein zusätzlicher Dauer-Loop würde nur nerven.*

## 3. Rollen-Fähigkeiten

| Cue | Datei | Wann | Klang-Richtung |
|-----|-------|------|----------------|
| dash | `dash.wav` ✅ vorhanden | Speedster dasht | Reifenquietschen |
| dash_shockwave | `dash_shockwave.wav` | Speedster Stage-2 Doppel-Dash landet | dumpfer Impact |
| shield_up | `shield_up.wav` | Tank-Schild geht hoch | metallischer Clunk |
| earth_shockwave | `earth_shockwave.wav` | Earth-Schockwelle | tiefes Grollen |
| engineer_heal | `engineer_heal.wav` | Engineer-Passiv-Heal (alle 5 s) | weiches Heil-Glitzern — **organisch, kein Auto-Sound** |
| drone_deploy | `drone_deploy.wav` | Engineer setzt Drohne ab | Servo-Surren |

## 4. CARIAD-HUD-Echo

**Team-Entscheidung 2026-07-16:** Die drei elementaren HUD-Echos (`ice_ac_hiss`, `fire_engine`,
`earth_servo_hum`) sind **gestrichen** — die Element-Indikatoren leuchten weiterhin, bleiben aber
stumm. Nur LIDAR behält sein Audio-Echo.

| Cue | Datei | HUD-Indikator | Klang-Richtung |
|-----|-------|---------------|----------------|
| lidar_blip | `lidar_blip.wav` | LIDAR 🔴 (Gegner-Welle spawnt) | Radar-Blip |

⚠️ **Wird "onset-gated" abgespielt** (`ONSET_GAP` in `Sfx.gd`): Ein Event, das schnell
hintereinander feuert, spielt den Sound **nur einmal beim Aktivieren**, nicht bei jedem Tick
(SFX-02). Heißt für euch: Das Sample wird als *einzelner Anschlag* gehört, nicht als Loop.

## 5. Pickups, Übergänge, UI

| Cue | Datei | Wann | Klang-Richtung |
|-----|-------|------|----------------|
| xp_arrive | `xp_arrive.wav` + `xp_arrive_2.wav` (zufällige Variante) ✅ vorhanden | XP-Orb landet in der Leiste | Münz-Chime |
| exit_open | `exit_open.wav` | Sub-Room geschafft, Durchgang öffnet sich | Tor-Clunk — **wichtiges Signal**, das sagt den Spielern "hier lang" |
| transition | `transition.wav` ✅ vorhanden | Spieler gehen in den nächsten (Sub-)Raum | Whoosh |
| run_start | `run_start.wav` ✅ vorhanden | "GO!" nach dem 3-2-1-Countdown | Motor-Zündung / Aufheulen |
| ui_click | `ui_click.wav` ✅ vorhanden | irgendein Menü-Button | dezenter Blip |
| ui_navigate | `ui_navigate.wav` ✅ vorhanden | Karten-Auswahl mit A/D | dezenter Tick |
| ui_confirm | `ui_confirm.wav` ✅ vorhanden | Karte bestätigt | dezenter Bestätigungston |

*UI bewusst sehr leise und unauffällig — das ist Feedback, kein Statement.*

## 6. Priority-Stinger (reservierte Stimmen)

Das sind die 9 Momente, die **immer** durchkommen müssen. Dürfen länger und lauter sein.

| Cue | Datei | Wann | Klang-Richtung |
|-----|-------|------|----------------|
| kill_fanfare | `kill_fanfare.wav` ✅ vorhanden | Elite-Gegner stirbt | triumphaler Sting |
| boss_phase | `boss_phase.wav` ✅ vorhanden | Boss wechselt Phase | Mech-Brüllen / Alarm |
| boss_death | `boss_death.wav` | Boss stirbt | großes Auflösen |
| evolution | `evolution.wav` ✅ vorhanden | Spieler transformiert (Stage 2/3) | Transform-Sting |
| level_up | `level_up.wav` ✅ vorhanden | Team-Level-Up | triumphaler Aufstieg |
| downed | `downed.wav` ✅ vorhanden | Spieler geht zu Boden | Power-Down-Alarm |
| revive | `revive.wav` ✅ vorhanden | Spieler wiederbelebt | Power-Up-Chime |
| big_hit | `big_hit.wav` | schwerer Treffer auf einen Spieler | wuchtiger Impact |
| game_over | `game_over.wav` ✅ vorhanden | Team-Wipe, Game-Over-Screen | Niederlagen-Sting |

## 7. Musik-Stings

Nur **zwei** Momente kriegen eine Musik-Reaktion. Die legen sich *über* die laufende Musik, sie
unterbrechen sie nicht. Bewusst sparsam — sonst nutzt sich der Effekt ab.

| Cue | Datei (`res://assets/audio/…`) | Wann |
|-----|-------------------------------|------|
| evolution_sting | `evolution_sting.wav` | Evolution-Transform (~1–1.5 s) |
| boss_death_sting | `boss_death_sting.wav` | Boss stirbt, Loop endet |

*Boss-Phasenwechsel bleibt absichtlich SFX-only — sonst wäre die Musik-Ebene ständig am Reagieren.*

---

## Bewusst still gelassen

Damit's nicht zur Dauerbeschallung wird — diese Sachen kriegen **keinen** eigenen Cue:

- **Spinning Tires** → läuft über den `hit`-Tick.
- **Ice-Trail-Zone (Slow pro Gegner)** → würde bei Swarms zum Dauergeräusch.
- **Fire Burst** → läuft über den `hit`-Tick der Treffer.
- **Elementare HUD-Echos (AC/ENGINE/SEAT MASSAGE)** → gestrichen (2026-07-16), Indikatoren
  leuchten stumm.
- **Tank-Reflect** → hört man, wenn der reflektierte Schaden landet (`hit`).
- **Spawn-Telegraph pro einzelnem Gegner** → würde bei Swarms zum Maschinengewehr. Die hörbare
  Spawn-Identität ist stattdessen der `lidar_blip` bei den *Wellen*-Spawns.
- **Drohnen-Heal-Puls** → der Deploy-Sound reicht; ein Puls alle 3 s wäre Dauergeräusch.

---

## Für Entwickler

Neuen Cue hinzufügen = eine Zeile in `CUES` (`autoloads/Sfx.gd`) + `Sfx.play("name")` am
Trigger. Tippfehler im Namen geben eine `push_warning` (nicht stille Leere) — ein *fehlendes
File* dagegen ist bewusst still. Diese Datei und die `CUES`-Tabelle synchron halten.
