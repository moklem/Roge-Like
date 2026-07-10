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

| Datei | Canvas | Anzeige im Spiel | Perspektive | Prompt (Englisch) | Verwendung |
|---|---|---|---|---|---|
| `enemy-basic.png` | 256×256 | ~28 px | Frontal / leichte ¾-Ansicht (wie die Spieler-Bots) | Small hostile scrap robot, boxy body, single red glowing eye, rusty grey-red plating, aggressive stance | Standard-Gegner (aktuell rotes Quadrat); wird per Engine orange (Brand) / blau (Frost) getönt — neutrale Grundfarbe wählen |
| `enemy-elite.png` | 256×256 | ~48 px | Frontal / leichte ¾-Ansicht | Larger menacing elite scrap robot, spiked shoulder plating, purple glowing core and eyes, heavier silhouette than the basic enemy | Elite-Gegner (aktuell lila Quadrat); spawnt periodisch als Mini-Boss |
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
