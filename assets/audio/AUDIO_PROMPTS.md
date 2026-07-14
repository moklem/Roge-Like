# Audio-Prompt-Sheet — wie jeder Sound klingen soll

Begleitdokument zu [`AUDIO_CHECKLIST.md`](./AUDIO_CHECKLIST.md). Die Checkliste sagt **welche**
Dateien fehlen und wohin sie gehören. Dieses Dokument sagt **wie sie klingen sollen** — ein
fertiger, copy-paste-barer Prompt pro Cue.

**Prompts sind auf Englisch.** Nicht aus Angeberei: AI-Audio-Generatoren (ElevenLabs SFX, Stable
Audio, Optimizer usw.) sind auf englische Prompts trainiert und liefern damit deutlich zuverlässiger.
Wer die Sounds selbst aufnimmt oder in einem Sample-Pack sucht, liest den Prompt einfach als
Beschreibung.

---

## Bevor ihr irgendwas generiert: 6 Regeln, die für ALLE Cues gelten

Die kommen nicht aus dem Lehrbuch, sondern aus dem, was dieses Spiel technisch mit den Sounds macht.
Wenn ihr die ignoriert, klingt das Spiel im Gefecht wie Matsch — egal wie gut das Einzel-Sample ist.

1. **Knochentrocken. Kein Reverb, kein Delay, kein Hall-Tail.**
   Das ist die wichtigste Regel. In einem dichten Kampf feuern 20–40 Sounds pro Sekunde. Jeder
   Hall-Tail stapelt sich mit allen anderen zu einem einzigen Rauschbrei. Raum kommt später aus
   dem Bus, nicht aus dem Sample. Schneidet die Datei hart am Ende ab.

2. **Vorne dran keine Stille.** Die Datei muss *auf dem ersten Sample* losgehen. Auch 30 ms
   Anlauf machen aus einem Treffer-Feedback ein Nachklappern.

3. **Kurz. Kürzer als ihr denkt.** Die angegebenen Längen sind Obergrenzen, keine Ziele.

4. **Mono reicht.** Die Cues sind nicht im Raum positioniert, sie werden zentral abgespielt.
   Stereo-Breite bringt hier nichts und kostet nur Datei.

5. **Keine Melodie in Routine-Cues.** Der Code jittert die Tonhöhe jedes Abspielvorgangs um ±5–10 %,
   damit 30 Treffer hintereinander nicht wie ein Maschinengewehr klingen. Bei geräuschhaftem
   Material klingt das lebendig. Bei einem erkennbaren Melodie-Motiv klingt es *verstimmt*. Deshalb:
   Melodisches nur in den **Priority-Stingern** (Abschnitt 6) — die sind selten genug.

6. **Normalisiert liefern, Pegel ignorieren.** Die Lautstärke setzen wir pro Cue im Code
   (`CUES`-Tabelle in `autoloads/Sfx.gd`). Ihr müsst nichts leise machen.

**Welt-Kontext für den Prompt-Kopf** (könnt ihr bei generischen Generatoren voranstellen, wenn ein
Sound zu beliebig rauskommt):

> Video game sound effect for a top-down co-op roguelike. Cars that transform into robots fight
> through a ruined city. Comic-book art style: punchy, exaggerated, readable. Dry studio recording,
> no reverb, no music.

---

## 1. Kampf

### `enemy_die.wav` — normaler Gegner stirbt
**Länge:** 0.25–0.4 s · Läuft sehr oft — der muss auch beim 200. Mal noch okay sein.
> Small scrap-metal enemy crumpling and collapsing. A short, dry crunch of thin sheet metal
> buckling, with a few tiny bolts and metal shards scattering on concrete at the tail. Percussive,
> not explosive. Dry, close-miked, no reverb.

**Achtung:** Nicht als Explosion bauen. Explosionen haben Bass und Länge; beides stapelt sich, wenn
acht Gegner gleichzeitig sterben. Das hier ist ein *Knirschen*, kein Bumms.

---

## 2. Waffen — das sind alles Autoteile, das darf man hören

### `exhaust_flames.wav` — Auspuff-Flammen
**Länge:** 0.3–0.5 s
> A car exhaust pipe belching a short burst of flame. Gassy whoosh with a percussive backfire pop
> at the front, like a tuned exhaust on overrun. Throaty and fuel-rich, not a clean gas torch.
> Dry, no reverb.

### `antenna_beam.wav` — Antennen-Laser
**Länge:** 0.25–0.4 s
> A thin electric beam firing from a car antenna. A tight zap: fast electrical crackle into a
> bright, focused whine that cuts off hard. Clean and high-frequency, sci-fi but small — a
> desktop-sized laser, not a cannon. Dry, no reverb.

### `horn_shockwave.wav` — Hupen-Schockwelle
**Länge:** 0.4–0.6 s
> A car horn blast weaponised. Starts as a real, brassy dual-tone car horn honk, then immediately
> distorts and blooms into a low pressure-wave whump that pushes outward. Comedic and aggressive at
> the same time. Dry, no reverb.

**Das ist der Lieblings-Cue des Spiels** — hier darf das Auto-Thema am deutlichsten durchkommen.
Der Anfang muss unverkennbar als *echte Autohupe* lesbar sein, sonst ist der Gag weg.

### `airbag_arm.wav` — Airbag freigeschaltet
**Länge:** 0.3–0.5 s
> An airbag rapidly inflating. A sharp pneumatic pop followed by a fast fabric-and-air puff that
> settles into taut fullness. Confident and protective. Dry, no reverb.

### `airbag_break.wav` — Airbag fängt tödlichen Treffer ab
**Länge:** 0.4–0.6 s · Wichtiger Moment: Der Spieler wäre gerade gestorben.
> An inflated airbag bursting under a heavy impact. A blunt cloth-muffled slam, then a violent
> tearing of fabric and a rush of escaping air deflating away. Relief and violence together. Dry,
> no reverb.

---

## 3. Rollen-Fähigkeiten

### `dash.wav` — Speedster dasht
**Länge:** 0.2–0.35 s · Der Spieler hört den *ständig*. Darf niemals nerven.
> A car launching off the line. Short tire chirp on asphalt with a tight air whoosh past the
> listener. Sharp, athletic, over almost immediately. Dry, no reverb.

**Achtung:** Kein langgezogenes Burnout-Quietschen. Ein *Chirp*, kein Screech.

### `dash_shockwave.wav` — Doppel-Dash landet (Stage 2)
**Länge:** 0.4–0.6 s
> A speeding car slamming to a stop and releasing a shockwave. A deep body-impact whump with a
> fast outward air-pressure swell. Weighty, low-mid focused. Dry, no reverb.

### `shield_up.wav` — Tank-Schild geht hoch
**Länge:** 0.3–0.5 s
> Heavy armour plating slamming into place. A solid metallic clunk of a thick car door locking,
> followed by a brief low electric hum settling as an energy field engages. Reassuring and heavy.
> Dry, no reverb.

### `earth_shockwave.wav` — Earth-Schockwelle
**Länge:** 0.5–0.7 s
> A ground shockwave rolling outward. Deep sub-bass rumble with grinding stone and dirt, cracking
> earth. Heavy and geological — felt more than heard. Dry, no reverb.

**Achtung:** Der einzige Cue mit ordentlich Sub-Bass. Genau deshalb nur *einer* — mehr Bass in den
Routine-Cues und der Mix wird im Gefecht undurchhörbar.

### `engineer_heal.wav` — Engineer-Passiv-Heal (alle 5 s)
**Länge:** 0.4–0.6 s
> A gentle healing pulse. Warm, soft shimmer — like a bright bell blooming and fading, with a light
> airy sparkle. Organic, comforting, no metal, no machinery. Dry, no reverb.

**Bewusst KEIN Auto-Sound.** Der Heal ist der eine Moment, wo das Spiel warm sein darf. Wenn das
nach Servo klingt, ist die Wirkung weg. (Das ist auch der Grund, warum er sich vom Earth-Heal in
Abschnitt 4 unterscheiden *muss*.)

### `drone_deploy.wav` — Engineer setzt Drohne ab
**Länge:** 0.3–0.5 s
> A small drone deploying. Quick servo whir spinning up, a light mechanical click as it locks into
> position, and a soft electronic chirp confirming it is online. Small, precise, friendly robot.
> Dry, no reverb.

---

## 4. Elemente — als CARIAD-HUD-Echo

Diese vier hängen an den Auto-HUD-Anzeigen, die eh schon aufleuchten. **Der Witz des ganzen Spiels
steckt genau hier:** Es ist kein Fantasy-Element, es ist eine Fahrzeugfunktion, die durchdreht. Eis
ist keine Magie — es ist die Klimaanlage. Feuer ist kein Zauber — der Motor überhitzt.

Wer diese vier generisch als „ice spell / fire spell" baut, hat die Pointe verschenkt.

⚠️ **Alle vier werden als *einzelner Anschlag* gehört, nie als Loop** (der Code drosselt Dauereffekte
auf einen Ton beim Aktivieren). Also: klarer Attack vorne, sauberer Abschluss hinten. Baut kein
Loop-Segment, das mittendrin abgeschnitten wirkt.

### `ice_ac_hiss.wav` — Ice (HUD: „AC ❄️ COLD")
**Länge:** 0.4–0.6 s
> A car air-conditioning compressor kicking in hard. A pressurised refrigerant hiss with a
> mechanical clutch clunk at the front, and a cold crystalline shimmer riding on top as frost forms.
> Half machine, half ice. Dry, no reverb.

### `fire_engine.wav` — Fire (HUD: „ENGINE 🔥 OVERHEAT")
**Länge:** 0.4–0.6 s
> A car engine overheating and detonating. Metallic knocking and rattling under load, boiling
> coolant hiss, a stressed pressure release. Angry, mechanical, on the edge of failure. Dry, no
> reverb.

**Achtung:** Kein Lagerfeuer, kein Flammenwerfer. Das ist ein *Motorschaden*.

### `earth_servo_hum.wav` — Earth-Heal (HUD: „SEAT MASSAGE 🌿")
**Länge:** 0.5–0.7 s
> A luxury car massage seat activating. A smooth servo motor spinning up into a warm, low kneading
> hum with a soft pneumatic pulse. Comfortable, plush, slightly absurd. Dry, no reverb.

**Der beste Gag im ganzen Sound-Design.** Das Erd-Element heilt das Team — und klingt wie ein
Massagesitz in der Oberklasse. Bitte genau so ernst bauen, wie das klingt.

### `lidar_blip.wav` — Gegner-Welle spawnt (HUD: „LIDAR 🔴")
**Länge:** 0.3–0.5 s
> A vehicle LIDAR sensor detecting a threat. A clean synthetic radar ping followed by a short
> double alert blip — a car parking sensor that has found something much worse than a wall.
> Precise, digital, faintly ominous. Dry, no reverb.

---

## 5. Pickups, Übergänge, UI

### `xp_arrive.wav` — XP-Orb landet in der Leiste
**Länge:** 0.15–0.3 s · **Der meistgehörte Sound im Spiel.** Hunderte Male pro Run.
> A small pickup collect. A short, bright metallic coin-like chime with a fast attack and a quick
> clean decay. Satisfying, light, unobtrusive. Dry, no reverb.

**Der wichtigste Sound auf dieser ganzen Liste** — nicht weil er der dickste ist, sondern weil er
am häufigsten kommt. Wenn der nach 30 Sekunden nervt, nervt das ganze Spiel. Klein, weich, kein
scharfer Transient. Im Zweifel: leiser und runder als euer erster Instinkt.

### `exit_open.wav` — Durchgang öffnet sich
**Länge:** 0.5–0.8 s · Wichtiges Spielsignal, kein Deko-Sound.
> A heavy gate unlocking and grinding open. A deep mechanical clunk of a lock releasing, then stone
> and metal sliding apart. Clear, announcing, unmistakable. Dry, no reverb.

Der sagt dem Team „Raum geschafft, da lang." Muss **durch einen laufenden Kampf hörbar** sein und
darf sich mit keinem anderen Cue verwechseln lassen.

### `transition.wav` — nächster (Sub-)Raum wird betreten
**Länge:** 0.5–0.8 s
> A whoosh of moving into a new space. A smooth airy sweep with a subtle low swell underneath.
> Neutral, transitional, no drama. Dry, no reverb.

### `run_start.wav` — „GO!" nach dem Countdown
**Länge:** 0.8–1.2 s · Der erste Sound des Runs. Setzt den Ton für alles danach.
> A car engine igniting and revving hard. Starter motor cranking, engine catching, then an
> aggressive throttle blip. Confident, muscular, ready to go. Dry, no reverb.

### `ui_click.wav` — Menü-Button
**Länge:** 0.05–0.12 s
> A tiny UI button click. Short, soft, muted digital blip. Understated, barely there. Dry.

### `ui_navigate.wav` — Karten-Auswahl A/D
**Länge:** 0.05–0.12 s
> A tiny UI navigation tick. Very short muted click, slightly higher and lighter than a confirm.
> Understated. Dry.

### `ui_confirm.wav` — Karte bestätigt
**Länge:** 0.15–0.3 s
> A UI confirmation. A short warm two-note rise, soft and rounded. Positive but quiet — a small
> yes, not a fanfare. Dry.

**Die drei UI-Sounds bitte alle *unter* der Wahrnehmungsschwelle halten.** Sie sollen bestätigen,
dass der Klick angekommen ist — mehr nicht. Wenn man sie bewusst bemerkt, sind sie zu laut.

---

## 6. Priority-Stinger — hier darf's knallen

Diese 8 haben **reservierte Stimmen** im Code: Sie werden nie von Treffer-Ticks weggedrängt. Das
sind die Momente, an die sich Leute nach dem Spielen erinnern. Länger, lauter, musikalischer.
**Hier ist melodisches Material ausdrücklich erlaubt** (bei den Routine-Cues nicht, siehe Regel 5).

### `kill_fanfare.wav` — Elite-Gegner stirbt
**Länge:** 0.6–1.0 s
> A triumphant kill sting. A heavy metallic death crunch immediately answered by a short punchy
> brass-and-synth flourish. Rewarding, brief, celebratory. Slight reverb tail allowed.

### `boss_phase.wav` — Boss wechselt Phase
**Länge:** 1.0–1.5 s · Warnsignal: Der Boss wird jetzt gefährlicher.
> A boss escalating. A huge mechanical roar of a machine rebuilding itself, layered with a rising
> industrial alarm klaxon. Threatening, announcing, "it just got worse". Reverb allowed.

### `boss_death.wav` — Boss stirbt
**Länge:** 1.5–2.5 s · Der Höhepunkt des Loops.
> A colossal machine dying. A massive structural collapse — tearing metal, systems powering down in
> a descending whine, heavy debris settling. Final and total. Full reverb allowed.

### `evolution.wav` — Spieler transformiert (Stage 2/3)
**Länge:** 1.0–1.5 s · **Muss exakt in dieses Fenster passen** — die Animation ist gecappt.
> A car transforming into a robot. Fast cascading mechanical servos and metal plates locking into
> place, rising in pitch and intensity, resolving into a powerful energised hum as the new form
> comes online. Iconic, mechanical, triumphant. Reverb allowed.

**Das ist DER Sound des Spiels.** Wenn ihr nur Zeit für einen habt, nehmt diesen. Referenz ist
offensichtlich und darf es auch sein: das Transformations-Geräusch, das jeder im Ohr hat.

### `level_up.wav` — Team-Level-Up
**Länge:** 0.6–1.0 s
> A triumphant level-up. A bright ascending synth-and-bell flourish resolving upward. Clean,
> rewarding, unmistakably positive. Slight reverb allowed.

### `downed.wav` — Spieler geht zu Boden
**Länge:** 0.8–1.2 s · Muss durch jedes Chaos schneiden. Das Team muss es *hören*.
> A machine powering down in failure. A descending, sagging whine of systems dropping offline,
> with a low warning alarm underneath and a final heavy mechanical slump. Alarming, sad, urgent.
> Reverb allowed.

### `revive.wav` — Spieler wiederbelebt
**Länge:** 0.8–1.2 s · Die Antwort auf `downed`. Sollte als Gegenstück erkennbar sein.
> A machine powering back up. A rising energised hum with systems rebooting, resolving into a
> bright confident chime. Relief, rescue, back in the fight. Reverb allowed.

**Tipp:** Baut `downed` und `revive` als Paar — gleiche Klangfamilie, einmal fallend, einmal
steigend. Dann liest das Team sie auch mitten im Gefecht sofort richtig.

### `big_hit.wav` — schwerer Treffer auf einen Spieler
**Länge:** 0.4–0.7 s
> A heavy impact on an armoured vehicle. A deep, blunt metallic slam with a crunching dent and a
> short low-frequency thud. Painful and weighty. Minimal reverb.

---

## 7. Musik-Stings

Zwei Momente, mehr nicht. Diese legen sich **über die laufende Musik** — sie ersetzen sie nicht.
Heißt: Sie müssen mit beliebigem Untergrund funktionieren.

**Deshalb tonal zurückhaltend bleiben.** Ein klar in C-Dur stehender Sting kollidiert mit dem Track,
der zufällig gerade läuft. Perkussives und geräuschhaftes Material („swell", „riser", „impact",
„cymbal") verträgt sich mit allem; eine ausformulierte Akkordfolge nicht.

### `evolution_sting.wav` (→ `res://assets/audio/evolution_sting.wav`)
**Länge:** 1.0–1.5 s · liegt unter dem Transform-Moment
> A short orchestral-electronic swell of intensity. Rising strings and synth building with a
> percussive hit at the peak. Heroic, brief, no clear melody. Works layered over existing music.

### `boss_death_sting.wav` (→ `res://assets/audio/boss_death_sting.wav`)
**Länge:** 2.0–3.0 s · markiert das Ende des Loops
> A short triumphant resolve. A big cymbal-and-brass hit decaying into a satisfied low sustain.
> Conclusive, victorious, no clear melody. Works layered over existing music.

---

## Wenn ein Sound generiert wurde: der 30-Sekunden-Test

Bevor ihr eine Datei ablegt, einmal durchgehen:

- [ ] **Fängt sie sofort an?** Stille am Anfang → vorne abschneiden.
- [ ] **Hört sie sauber auf?** Hall-Fahne bei Routine-Cues → hart kürzen.
- [ ] **20× hintereinander abspielen.** Nervt sie? Dann ist sie zu lang, zu laut oder zu scharf.
      Das ist der Test, der Cues rettet — besonders `xp_arrive`, `hit` und `enemy_die`.
- [ ] **Erkennt man sie im Chaos?** Vor allem `exit_open`, `downed`, `revive`, `boss_phase`.
- [ ] **Klingt sie nach Auto?** Bei allen Waffen und Element-Echos: ja, bitte.
      Bei `engineer_heal`: ausdrücklich nein.

Datei unter dem Pfad aus [`AUDIO_CHECKLIST.md`](./AUDIO_CHECKLIST.md) ablegen — sie spielt sofort,
ohne Code-Change.
