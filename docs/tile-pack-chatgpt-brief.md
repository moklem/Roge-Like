# Tile-Pack Brief für ChatGPT — Erba / Altstadt / Altenburg

Ziel: Alle Welt-Tiles der drei Biome neu generieren, im **gleichen Stil wie die
Charaktere** (hi-res Cel-Shaded-Illustration, siehe `assets/Speedstar_lvl_1.png`).
Die Tiles ersetzen die bisherige Pixel-Art (Cainos, Kenney, janv2).

## Workflow mit ChatGPT

1. Zuerst den **Global Style Prompt** (unten) als Kontext geben.
2. Pro Biome mit dem **Boden-Basistile** anfangen — das wird die Stilreferenz.
3. Alle weiteren Tiles des Biomes mit *"same style, same palette, same lighting
   as the previous tile"* anfordern (idealerweise im selben Chat-Thread).
4. Jedes Tile als **einzelnes PNG** herunterladen und unter dem angegebenen
   Dateinamen ablegen (Ordner: `assets/gpt-tiles/<biome>/`).
5. Props unbedingt **mit transparentem Hintergrund** anfordern; Böden und
   Wände sind vollflächig (opak).

## Technische Vorgaben (gelten für jedes Tile)

| Eigenschaft | Wert |
|---|---|
| Größe | **256×256 px** pro Tile (Obstacles teils 512×512, siehe Tabellen) |
| Format | PNG; Props mit Alpha, Böden/Wände opak |
| Perspektive | Böden/Oberseiten: exakt top-down (90°). Wand-Faces: Frontansicht der Fassade |
| Anzeige im Spiel | wird auf **~32–64 px** runterskaliert (32-px-Welt-Grid) → **große, klare Formen, kein feines Rauschen** |
| Outlines | saubere dunkle Konturen wie bei den Charakteren, mittlere Strichstärke |
| Shading | Cel-Shading, 2–3 Tonstufen, Licht einheitlich von **oben links** |
| Kachelbarkeit | Boden-Tiles müssen **nahtlos** kacheln (Ränder verlaufen neutral, keine auffälligen Elemente am Rand) |
| Pro Bild | genau **ein** Tile, bildfüllend, kein Raster, kein Text, kein Wasserzeichen |
| **Keine Dächer** | Wand-Oberseiten sind flache dunkle Stein-/Putzflächen von oben — niemals Dachziegel, Giebel oder Schrägen. Obstacles sind Bodenobjekte, keine Gebäude |

## Global Style Prompt (an ChatGPT geben, auf Englisch)

```
You are generating a cohesive tile set for a top-down 2.5D roguelike game.
Art style: high-resolution cel-shaded illustration with clean dark outlines
and soft 2–3 step shading — matching hand-drawn cartoon robot characters
(NOT pixel art, NOT photorealistic, NOT painterly-blurry).
Every tile: one single square image, 256×256 px, flat top-down view for
floors and surfaces, straight front view for wall facades.
Bold readable shapes only — the tiles are displayed very small in game.
Consistent light from the top-left in every image. Floor tiles must tile
seamlessly: keep edges neutral, no distinct objects touching the border.
No text, no watermark, no grid, no multiple tiles per image, and NO ROOFS —
wall tops are flat dark stone seen from above, never shingles or gables.
```

---

## Biome 1 — ERBA (Park-Insel, Wiesen & Steinmauern)

Palette: sattes Gras-Grün, warmes Beige/Grau für Stein, bunte Blumen-Akzente.
Ordner: `assets/gpt-tiles/erba/`

| Datei | Größe | Alpha | Prompt-Beschreibung (Englisch) |
|---|---|---|---|
| `floor-grass-b.png` | 256 | nein | Lush green grass meadow, seamless, subtle blade texture, calm and even |
| `floor-grass-flowers.png` | 256 | nein | Same grass with small scattered wildflowers (white/yellow/violet), flowers stay away from edges |
| `floor-grass-tufts.png` | 256 | nein | Same grass with a few taller grass tufts and clover |
| `floor-connector.png` | 256 | nein | Packed stone/gravel park path, neutral grey-beige, seamless |
| `wall-face-a.png` | 256 | nein | Front view of a low park stone wall: beige-grey masonry blocks, moss in the joints, bottom edge meets the ground |
| `wall-face-b.png` | 256 | nein | Variant B: same wall with slightly different block layout and a small ivy patch |
| `wall-top.png` | 256 | nein | Flat top surface of that stone wall seen from directly above — dark desaturated stone, NO roof |
| `obstacle-rocks.png` | 512 | ja | Top-down pile of large rounded boulders (fills most of the canvas, reads as one 2×2 blocker), transparent background |
| `prop-flowerpatch.png` | 256 | ja | Small cluster of wildflowers, top-down, transparent background |
| `prop-pebbles.png` | 256 | ja | Few small scattered pebbles, top-down, transparent background |

## Biome 2 — ALTSTADT (Bamberger Gassen, Kopfsteinpflaster & Fachwerk)

Palette: warmes Grau-Braun für Pflaster, Sandstein-Beige + dunkles Fachwerk-Braun,
Akzente in Laternen-Gold und Moos-Grün.
Ordner: `assets/gpt-tiles/altstadt/`

| Datei | Größe | Alpha | Prompt-Beschreibung (Englisch) |
|---|---|---|---|
| `floor-cobble-a.png` | 256 | nein | Old-town cobblestone street, rounded grey-brown stones, seamless |
| `floor-cobble-b.png` | 256 | nein | Variant B: same cobblestone, slightly darker with worn patches |
| `floor-cobble-c.png` | 256 | nein | Variant C: same cobblestone with moss between some stones |
| `floor-grass-patch.png` | 256 | nein | Cobblestone partially overgrown with a mossy grass patch, seamless with the cobble tiles |
| `floor-drain.png` | 256 | nein | Same cobblestone with a small round iron drain cover in the center |
| `floor-connector.png` | 256 | nein | Smooth dark paved road surface, subtle wear, seamless |
| `wall-face-a.png` | 256 | nein | Front view of a half-timbered old-town house wall: beige plaster with dark brown timber beams, one small window with shutters |
| `wall-face-b.png` | 256 | nein | Variant B: sandstone house wall with a wooden door |
| `wall-face-c.png` | 256 | nein | Variant C: plaster wall with timber beams and a small hanging flower box |
| `wall-top.png` | 256 | nein | Flat top of the wall from directly above — dark stone/plaster surface, NO roof tiles |
| `obstacle-fountain.png` | 512 | ja | Top-down round old stone fountain with water (reads as one 2×2 blocker), transparent background |
| `obstacle-stall.png` | 512 | ja | Top-down wooden market stall table with goods, NO canopy/roof, transparent background |
| `prop-lantern.png` | 256 | ja | Top-down black iron street lantern with warm glow, transparent background |
| `prop-barrel.png` | 256 | ja | Top-down wooden barrel, transparent background |
| `prop-crates.png` | 256 | ja | Top-down small stack of wooden crates, transparent background |
| `prop-flowerbox.png` | 256 | ja | Top-down wooden planter box with flowers, transparent background |
| `prop-sign.png` | 256 | ja | Top-down standing wooden signpost, transparent background |

## Biome 3 — ALTENBURG (Burg, Stein & Fackelschein)

Palette: kühles dunkles Steingrau, warme Fackel-Orange-Akzente, dunkles Holz,
tiefrote Banner. Düsterer als die anderen Biome (Boss-Gebiet).
Ordner: `assets/gpt-tiles/altenburg/`

| Datei | Größe | Alpha | Prompt-Beschreibung (Englisch) |
|---|---|---|---|
| `floor-flagstone-a.png` | 256 | nein | Castle interior floor of large grey stone flagstones, seamless |
| `floor-flagstone-b.png` | 256 | nein | Variant B: same flagstones, some cracked |
| `floor-flagstone-c.png` | 256 | nein | Variant C: same flagstones, darker and slightly damp |
| `floor-rubble.png` | 256 | nein | Same flagstones with small rubble and dust patches |
| `floor-carpet.png` | 256 | nein | Same flagstones with a worn deep-red carpet strip running across (for the boss arena), seamless along the carpet direction |
| `wall-face-a.png` | 256 | nein | Front view of a massive castle wall: large dark stone blocks, bottom edge meets the floor |
| `wall-face-b.png` | 256 | nein | Variant B: same wall with a mounted burning torch |
| `wall-face-c.png` | 256 | nein | Variant C: same wall with a hanging dark-red banner |
| `wall-top.png` | 256 | nein | Flat top of the castle wall from directly above — very dark stone, NO roof |
| `obstacle-pillar.png` | 512 | ja | Top-down broken stone pillar with rubble around its base (2×2 blocker), transparent background |
| `obstacle-altar.png` | 512 | ja | Top-down dark stone boss altar platform with glowing runes (2×2), transparent background |
| `prop-torch.png` | 256 | ja | Top-down standing torch brazier with fire glow, transparent background |
| `prop-barrel.png` | 256 | ja | Top-down old dark wooden barrel with iron bands, transparent background |
| `prop-bones.png` | 256 | ja | Top-down small scattered bones/skull, transparent background |
| `prop-chains.png` | 256 | ja | Top-down coiled heavy iron chain, transparent background |

---

## Qualitäts-Checkliste pro Tile (vor dem Ablegen prüfen)

- [ ] Stil passt zur Biome-Referenz (erstes Boden-Tile) — Outline-Dicke, Palette, Licht von oben links
- [ ] Auf ~32 px runterskaliert noch klar lesbar (im Zweifel: Zoom raus / Thumbnail anschauen)
- [ ] Boden-Tiles: 2×2 nebeneinander gelegt keine sichtbaren Kanten/Wiederholungsmuster am Rand
- [ ] Props/Obstacles: sauberer Alpha-Hintergrund, keine weißen Ränder
- [ ] Kein Dach, kein Text, kein Wasserzeichen, nur ein Tile pro Bild

## Was danach im Projekt passiert (nicht Teil des ChatGPT-Briefs)

- Neue TileSet-Sources pro Biome (tile_size 256, TileMap-Node-Scale 0.125 →
  identisches 32-px-Grid on-screen, gleiches Prinzip wie `TileSetErba` @ 1.0).
- `RoomLayouts.gd` / `RoomBuilder.gd`: Konstanten auf die neuen Sources umziehen,
  Hash-Variation auf die neuen Varianten-Anzahlen anpassen, Wall-Top statt
  „Cap mit Modulate" optional als eigene Textur.
- Neue Props in die Layer-1-Scatter-Logik aufnehmen (wie ERBA-Pebbles heute).
