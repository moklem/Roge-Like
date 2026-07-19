# Tile-Asset-Briefing — AutoBonk (Top-Down Roguelike, Godot)

Du generierst das komplette Tile-Set für ein Top-Down-Spiel mit drei Räumen:
**ERBA-Insel (Park)**, **Altstadt** und **Burg** — angelehnt an Bamberg, mit leichten
Cyber-Akzenten. Charaktere, Auflösung und Map-Aufbau sind fix. Deine Aufgabe:
Texturen, die zu den mitgelieferten Charakter-Sprites passen.

---

## 1. Stil (nicht verhandelbar)

**Orientiere dich exakt an den angehängten Player- und Enemy-Sprites.** Das ist die
Stil-Referenz für ALLES.

- **Flat-Cartoon, KEIN Pixel-Art, KEIN Painterly/Fotorealismus.**
- **Dicke, dunkle Outlines** um alle Formen — gleiche relative Linienstärke wie bei
  den Charakteren.
- **Flächige Farben:** pro Fläche ein Basiston + maximal ein Schattenton (Cel-Shading).
  Keine Verläufe, keine Texturkörnung, kein Rauschen.
- **Licht kommt immer von oben / leicht oben-links.** Bei jedem Asset, ausnahmslos.
- **Cyber-Akzente:** sparsam (~5–10 % der Assets), immer in **Neon-Cyan** (wie die
  Roboter-Augen der Charaktere). Beispiele: eine glühende Leitung im Boden, ein kleines
  Hologramm-Schild, eine Neon-Kante an einer Laterne. Nie flächig, nur Akzent.

**Englischer Prompt-Baustein für jede Generierung:**
> flat cartoon game art style, bold thick dark outlines, cel shading with flat colors
> and one shadow tone, no texture noise, no painterly detail, clean vector look,
> light from top-left

---

## 2. Das 2,5D-Wandsystem (wichtigstes Konzept)

Jede Wand besteht aus zwei getrennten Texturen. Die Engine setzt sie zusammen — du
lieferst nur die zwei Teile:

1. **CAP (Mauerkrone):** die Oberseite der Mauer, **exakt von oben** gesehen (90°
   Draufsicht). Große unregelmäßige Steinplatten mit Fugen. **Hellste Fläche im
   Raum** — heller als der Boden. KEINE Seitenansicht, keine Ziegelreihen sichtbar.
2. **FACE (Mauerfront):** die senkrechte Vorderseite, **exakt frontal** gesehen.
   2–3 Reihen Mauerwerk. **Gleiche Steinsorte/Farbfamilie wie das Cap** — die Engine
   dunkelt das Face selbst ab (liefere es in normaler Helligkeit!). Untere Kante =
   Mauerfuß (dort darf Moos/Dreck ansetzen, das liegt später auf dem Boden auf).

**Wichtig:** Cap und Face müssen wie EINE Mauer wirken (gleiche Steine, gleiche
Fugenfarbe, gleiche Outlines). Schatten baut die Engine — **backe NIEMALS
Schlagschatten in Boden- oder Wandtexturen ein.**

Das gleiche Höhen-Prinzip gilt für Props: Objekte werden aus ~70° Top-Down-Sicht
gezeichnet (Oberseite sichtbar, Vorderseite verkürzt), stehen „auf" dem Boden.

---

## 3. Technische Vorgaben (Pipeline-Anforderungen)

| Regel | Wert |
|---|---|
| Format | PNG, quadratisch, **mindestens 1024×1024** |
| Flächen-Texturen (Boden, Cap, Face) | **randlos gefüllt** (full-bleed, kein Rand/Hintergrund) |
| Props/Objekte | EIN Objekt, zentriert, auf **reinweißem Hintergrund** |
| Kachelbarkeit Boden + Cap | **nahtlos in beide Richtungen** (seamless tileable) |
| Kachelbarkeit Face | nahtlos **horizontal** |
| Outline-Dicke | ~1,5–2 % der Bildbreite (bei 1024 px: **16–20 px**) — die Bilder werden stark runterskaliert, dünnere Linien verschwinden! |
| Detailgröße | Elemente (Steine, Büschel, Platten) mindestens **1/10 der Bildbreite**. Keine feinen Details, kein Mikro-Kram — fällt beim Skalieren weg |
| Dateinamen | **exakt wie in den Listen unten** (die Build-Pipeline liest diese Namen) |

---

## 4. Konsistenz-Guidelines (für ALLE Tiles)

1. **Eine Master-Palette pro Raum**, abgeleitet aus den Charakterfarben. Lege sie beim
   Style-Sample fest und verwende sie dann für JEDES Asset des Raums wieder. Begrenzt
   halten (~8–12 Farben + Cyan-Akzent).
2. **Böden ruhig, Wände & Props laut.** Böden sind die Bühne: niedriger Kontrast,
   Deko-Elemente nur 1–2 Helligkeitsstufen vom Grundton entfernt. Die Outlines-Charaktere
   müssen davor „poppen". Wände/Props dürfen vollen Kontrast + Outlines haben.
3. **Varianten müssen austauschbar sein:** Boden-Varianten a/b/c gleicher Grundton,
   gleiche Detaildichte — beim Blinzeln nicht unterscheidbar. Sie werden zufällig
   gemischt; eine „laute" Variante erzeugt sichtbares Raster.
4. **Übergänge:** Texturen enden an den Rändern immer in „neutralem" Material
   (Fuge, Gras-Basis, Asphalt-Grundton) — nie mitten in einem Stein/Objekt. So
   entstehen saubere Kanten, wo verschiedene Böden aneinanderstoßen.
5. **Gleiche Fugen-/Schattenfarbe** innerhalb eines Raums (ein dunkler Ton für alle
   Fugen, Outlines und Schattenflächen — nicht pro Asset neu erfinden).
6. **Squint-Test vor Abgabe:** Bild verkleinern/blinzeln — man muss noch erkennen:
   Boden ruhig, Steine als Formen lesbar, Outlines vorhanden.

---

## 5. Workflow — GENAU in dieser Reihenfolge

Pro Raum gilt: **erst Style-Sample, dann Freigabe abwarten, dann Vollproduktion.**
Nicht vorproduzieren!

### Schritt 1 — Style-Sample ERBA
Generiere NUR diese 3 Assets und zeige sie zur Freigabe:
`floor-grass-a`, `wall-cap-a`, `wall-face-a`
→ Ich winke ab oder fordere Korrekturen. Erst nach meinem Go: Schritt 2.

### Schritt 2 — Vollproduktion ERBA (komplette Liste unten)

### Schritt 3 — Style-Sample Altstadt (`floor-cobble-a`, `wall-cap-a`, `wall-face-a`)
→ Freigabe abwarten. Gleiche Palette-Disziplin, neues Thema.

### Schritt 4 — Vollproduktion Altstadt

### Schritt 5 — Style-Sample Burg (`floor-stone-a`, `wall-cap-a`, `wall-face-a`)
→ Freigabe abwarten.

### Schritt 6 — Vollproduktion Burg

---

## 6. Asset-Listen

### Raum 1: ERBA-Insel (Park — Wiese, Steinmauern, Parkmobiliar)
Ordner: `erba/`

| Datei | Typ | Beschreibung |
|---|---|---|
| `floor-grass-a.png` | Boden | Wiese, satt grün, vereinzelte outlined Grasbüschel |
| `floor-grass-b.png` | Boden | Variante — gleicher Ton, andere Büschel-Anordnung |
| `floor-grass-c.png` | Boden | Variante |
| `floor-grass-tufts.png` | Boden | Wiese mit mehr/höheren Büscheln |
| `floor-grass-flowers.png` | Boden | Wiese mit wenigen kleinen Blumen (dezent!) |
| `floor-slabs.png` | Boden | Wiese mit eingelassenen Steinplatten |
| `floor-connector.png` | Boden | Steinweg/Straße (Verbindungskorridor) |
| `wall-cap-a.png` | Wand-Cap | Helle Steinplatten von oben (siehe Abschnitt 2) |
| `wall-cap-b.png` | Wand-Cap | Variante |
| `wall-face-a.png` | Wand-Face | Steinmauer frontal, Mauerfuß mit etwas Moos |
| `wall-face-b.png` | Wand-Face | Variante |
| `obstacle-rocks.png` | Prop (weiß hinterlegt) | Felshaufen, ~70°-Sicht |
| `prop-pebbles.png` | Prop | Paar Kiesel (groß genug! min. 1/10 Bildbreite) |
| `prop-stump.png` | Prop | Baumstumpf |
| `prop-flowerpatch.png` | Prop | Blumenfleck |
| `prop-bush.png` | Prop | Busch |
| `prop-bench.png` | Prop | Parkbank (Cyber-Akzent erlaubt: kleines Neon-Detail) |

### Raum 2: Altstadt (Fachwerk-Altstadt — Kopfsteinpflaster, Häuserwände)
Ordner: `altstadt/`

| Datei | Typ | Beschreibung |
|---|---|---|
| `floor-cobble-a.png` | Boden | Kopfsteinpflaster, warmes Graubraun, ruhig |
| `floor-cobble-b.png` | Boden | Variante |
| `floor-cobble-c.png` | Boden | Variante |
| `floor-grass-patch.png` | Boden | Moos/Gras-Fleck zwischen Pflaster (Mix-Tile) |
| `floor-road.png` | Boden | Gepflasterte Straße (Verbindungskorridor) |
| `wall-cap-a.png` | Wand-Cap | Helle Mauerkrone von oben, städtischer Stein |
| `wall-cap-b.png` | Wand-Cap | Variante |
| `wall-face-a.png` | Wand-Face | Hauswand frontal: Fachwerk/Sandstein-Sockel |
| `wall-face-b.png` | Wand-Face | Variante |
| `obstacle-roof.png` | Prop (weiß hinterlegt) | Hausdach von oben (rote Ziegel, Cartoon) |
| `prop-lantern.png` | Prop | Straßenlaterne (Cyber: cyan Leuchte statt Gaslicht) |
| `prop-barrel.png` | Prop | Holzfass |
| `prop-crate.png` | Prop | Kiste |
| `prop-sign.png` | Prop | Kleines Hologramm-/Neon-Schild (Haupt-Cyber-Akzent) |

### Raum 3: Burg Altenburg (Burghof — Stein, düsterer, fackelbeleuchtet)
Ordner: `burg/`

| Datei | Typ | Beschreibung |
|---|---|---|
| `floor-stone-a.png` | Boden | Steinboden, kühles Grau, große Platten, ruhig |
| `floor-stone-b.png` | Boden | Variante |
| `floor-stone-c.png` | Boden | Variante |
| `floor-stone-cracked.png` | Boden | Steinboden mit Rissen/fehlender Platte (dezent) |
| `wall-cap-a.png` | Wand-Cap | Burgmauer-Krone von oben, wuchtige Blöcke |
| `wall-cap-b.png` | Wand-Cap | Variante |
| `wall-face-a.png` | Wand-Face | Burgmauer frontal, große dunkle Quader |
| `wall-face-b.png` | Wand-Face | Variante |
| `obstacle-rubble.png` | Prop (weiß hinterlegt) | Trümmerhaufen/eingestürzte Steine |
| `prop-torch.png` | Prop | Wandfackel-Ständer (Flamme darf cyan-blau sein — Cyber) |
| `prop-banner.png` | Prop | Zerrissenes Banner |
| `prop-barrel.png` | Prop | Fass (darf mit Altstadt identisch sein) |

---

## 7. Checkliste pro Asset (vor Abgabe selbst prüfen)

- [ ] Outlines dick genug (16–20 px bei 1024)?
- [ ] Flat Colors, kein Painterly, kein Pixel-Art?
- [ ] Licht von oben-links?
- [ ] Boden: ruhig/low-contrast? Wand/Prop: kräftig mit Outlines?
- [ ] Flächen nahtlos kachelbar, Ränder enden in neutralem Material?
- [ ] Cap = reine Draufsicht? Face = rein frontal? Gleiche Steinfamilie?
- [ ] Keine eingebackenen Schlagschatten?
- [ ] Palette des Raums eingehalten, Cyan nur als Akzent?
- [ ] Exakter Dateiname aus der Liste?
