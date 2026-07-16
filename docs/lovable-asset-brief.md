# Lovable Asset-Brief — Verbleibende Placeholder

Diese Assets sind im Spiel noch **farbige Platzhalter-Rechtecke** (ColorRects) und
brauchen echte Grafiken. Stil-Referenz: die vorhandenen Charakter-Bots
(`assets/active/players/`) und die Welt-Tiles (`assets/lovableassats/`) —
hochauflösende Cel-Shading-Illustration mit sauberen dunklen Outlines,
2–3 Schattierungsstufen, Licht von **oben links**, KEIN Pixel-Art.

## Technische Vorgaben (gelten für jedes Asset)

| Eigenschaft | Wert |
|---|---|
| Format | PNG mit **transparentem Hintergrund** (kein weißer Hintergrund!) |
| Inhalt | genau **ein** Objekt, bildfüllend (kaum Rand), kein Text, kein Wasserzeichen |
| Licht | einheitlich von oben links |
| Anzeige im Spiel | wird stark runterskaliert (siehe Spalte) → **große, klare Formen** |
| Ablage | `assets/lovableassats/entities/` |

## Global Style Prompt (für Lovable, Englisch)

```
Cohesive game sprites for a top-down 2.5D roguelike. Art style: high-resolution
cel-shaded illustration with clean dark outlines and soft 2-3 step shading,
matching hand-drawn cartoon robot characters (NOT pixel art). One single object
per image, transparent background, consistent light from the top-left.
Bold readable silhouettes - sprites are displayed very small in game.
```

## Asset-Liste

> Update: Die beiden Standard-Gegner haben inzwischen animierte Sprites
> (`assets/active/enemies/enemy_1_*` / `enemy_2_*`) — es fehlen noch Elite,
> Boss, Projektil, XP-Orb und Heildrohne.

| Datei | Canvas | Anzeige im Spiel | Perspektive | Prompt (Englisch) | Verwendung |
|---|---|---|---|---|---|
| `enemy-elite.png` | 256×256 | ~48 px | Frontal / leichte ¾-Ansicht (wie die Spieler-Bots) | Larger menacing elite scrap robot, spiked shoulder plating, purple glowing core and eyes, heavier silhouette than the basic enemies | Elite-Gegner (aktuell lila Quadrat); spawnt periodisch als Mini-Boss |
| `boss.png` | 512×512 | ~96 px | Frontal / leichte ¾-Ansicht | Huge intimidating boss robot, bulky armored chassis, glowing red core, battle damage, dominating silhouette | Endboss in der Burg (aktuell dunkelrotes Quadrat); Phasen werden per Engine rot getönt — Grundfarbe dunkelgrau/rot |
| `bullet-player.png` | 128×64 | ~8×4 px | Seitlich, Flugrichtung **nach rechts** | Small glowing yellow-orange bolt projectile with a short motion trail, pointing right | Spieler-Projektil (aktuell gelbes Rechteck); wird zur Flugrichtung rotiert |
| `xp-orb.png` | 128×128 | ~16 px | Top-down / neutral | Small glowing golden screw-nut energy orb, soft yellow glow halo | XP-Drop von Gegnern (aktuell gelbes Quadrat); Roboter-Thema: Schraube/Mutter statt Kugel möglich |
| `heal-drone.png` | 256×256 | ~28 px | Frontal / leichte ¾-Ansicht, schwebend | Small friendly hovering repair drone, rounded white-green body, green cross emblem, tiny rotor or thruster glow | Engineer-Heildrohne (aktuell nur Code-Zeichnung); schwebt neben dem Spieler |

## Hinweise

- **Keine weißen Hintergründe einbacken** — die Tiles aus der letzten Lieferung
  (Steine, Dach, Schutt) mussten nachträglich freigestellt werden. Direkt mit
  Alpha exportieren.
- Gegner/Boss schauen am besten **leicht nach links** (wie die Spieler-Bots) —
  die Engine spiegelt bei Bewegung nach rechts automatisch.
- Die kleinen türkisen Glitzer-Artefakte aus der letzten Generation vermeiden
  (kamen in wall-cap/floor-Tiles vor).
- Nach dem Ablegen in `assets/lovableassats/entities/` Bescheid geben — die
  Szenen (Enemy, EliteEnemy, Boss, Bullet, XpOrb, HealDrone) müssen dann von
  ColorRect auf Sprite2D umgestellt werden.

---

## Nachtrag 2026-07-16 — Boden-Effekte (Ice-Patch + Dash-Skidmarks)

Diese vier sind im Code bereits **fertig verdrahtet (Safe-Load)**: PNG unter dem
angegebenen Pfad ablegen → erscheint im Spiel, kein Code-Schritt nötig. Fehlt die
Datei, bleibt der bisherige prozedurale Platzhalter aktiv.

Ablage: `assets/active/elements/` (Ordner neu anlegen)

| Datei | Canvas | Anzeige im Spiel | Perspektive | Prompt (Englisch) | Verwendung |
|---|---|---|---|---|---|
| `ice_trail_1.png` + `ice_trail_2.png` (2 Varianten) | 256×256 | ~44 px | Exakt top-down | A roughly circular irregular patch of magical ice frozen onto the ground: pale ice-blue sheet with jagged crystalline edges, a few small sharp ice crystals poking up, thin white frost cracks, one or two cel-shaded highlight facets. Palette: pale ice blue and white, deeper cyan-blue in the cracks. Irregular silhouette, never a perfect circle | Frostflächen des Ice-Elements (Slow-Zone hinter dem Spieler); Engine dreht zufällig in 90°-Schritten |
| `skid_fire.png` | 256×128 | ~26×13 px | Top-down, Streifen zeigen **nach rechts** | Two short parallel tire skid streaks burned into the ground, scorched black-orange with tiny ember glow and one or two small flame wisps licking off the trailing edge, fading out toward the left | Dash-Spur des Speedsters mit Feuer-Element; Engine rotiert zur Bewegungsrichtung |
| `skid_ice.png` | 256×128 | ~26×13 px | Top-down, Streifen zeigen **nach rechts** | Two short parallel frozen tire skid streaks, pale ice-blue frost trails with tiny frost crystals along the edges and a faint cold shimmer, fading out toward the left | Dash-Spur mit Ice-Element |
| `skid_earth.png` | 256×128 | ~26×13 px | Top-down, Streifen zeigen **nach rechts** | Two short parallel tire skid streaks torn into earth, dark green-brown gouges with small kicked-up soil crumbs and one or two tiny leaves/sprouts along the edges, fading out toward the left | Dash-Spur mit Earth-Element |

Hinweise:
- Skids: die **rechte Kante ist die frische Seite** (dort war der Reifen zuletzt),
  nach links ausfadend/ausdünnend — die Engine setzt ~8 Stempel pro Dash hintereinander,
  das Ausfaden pro Stempel macht die Gesamtspur organisch.
- Alle vier: transparenter Hintergrund, ein Objekt pro Bild, keine Schatten einbacken
  (Boden-Effekte werfen keinen).

> ✅ **Alle 5 Dateien geliefert und eingebaut (2026-07-16)** — saubere Alpha-Kanäle,
> Richtung stimmt, liegen unter `assets/active/elements/` und sind im Spiel aktiv.
