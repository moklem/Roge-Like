# Design Asset Checklist — Roge-Like

All assets replace placeholders in `assets/placeholders/`. Final files should be dropped in-place at the same paths so no code changes are needed.

**Base grid:** 32×32 (enemies, players, tiles) | 24×24 (pickups) | 16×16 (projectiles) | variable (UI)

**Style:** Arcade / game-jam silhouette art. Car-themed visual language throughout (wheels, gears, exhaust, antennas, airbags visible in design). Role colors established: Tank = steel blue, Speedster = orange, Engineer = lime green.

---/b

## Phase 5–6: Characters & Core Pickups

### Player Sprites — 9 sprites total (3 roles × 3 stages)

Each role evolves through 3 visual stages as the player levels up:
- **Stage 1 — Normal Car:** Recognizable vehicle shape, role-colored, no humanoid features
- **Stage 2 — Proto-Bot:** Raw skeletal robot mid-transformation; exposed parts, no armor, limbs visible
- **Stage 3 — Full AutoBot:** Fully armored, complete robot form; role color prominent

1. Tank — Stage 1 (Normal Car) `32×32` → `assets/placeholders/players/player_tank.png`
2. Tank — Stage 2 (Proto-Bot) `32×32`
3. Tank — Stage 3 (Full AutoBot) `32×32`
4. Speedster — Stage 1 (Normal Car) `32×32` → `assets/placeholders/players/player_speedster.png`
5. Speedster — Stage 2 (Proto-Bot) `32×32`
6. Speedster — Stage 3 (Full AutoBot) `32×32`
7. Engineer — Stage 1 (Normal Car) `32×32` → `assets/placeholders/players/player_engineer.png`
8. Engineer — Stage 2 (Proto-Bot) `32×32`
9. Engineer — Stage 3 (Full AutoBot) `32×32`

### Role & Element Icons (UI)

Used in the lobby, HUD, and level-up cards to identify roles and element types.

10. Role icon — Tank (shield / heavy armor aesthetic) `24×24`
11. Role icon — Speedster (lightning bolt / speed lines) `24×24`
12. Role icon — Engineer (wrench / gear / tool aesthetic) `24×24`
13. Element icon — Fire (flame) `24×24`
14. Element icon — Ice (snowflake) `24×24`
15. Element icon — Earth (plant / ground) `24×24`

### Enemy Sprites

16. Basic Enemy `32×32` → `assets/placeholders/enemies/basic_enemy.png`
17. Fast Enemy `32×32` → `assets/placeholders/enemies/fast_enemy.png`
18. Tank Enemy `32×32` → `assets/placeholders/enemies/tank_enemy.png`

### Projectiles

19. Player bullet (basic) `16×16` → `assets/placeholders/projectiles/player_bullet.png`
20. Enemy bullet `16×16` → `assets/placeholders/projectiles/enemy_bullet.png`

### Weapon Effect Sprites (replace in-game ColorRects)

21. Exhaust Flames — orange cone / spray effect (variable size, centered on player)
22. Spinning Tires — dark gray spinning disc `16–24×16–24`
23. Antenna Beam — cyan-teal narrow beam (rectangular, variable length)
24. Horn Shockwave — yellow expanding ring (scale-animated)
25. Airbag Shield — yellow protective ring around player (two-layer)

### Pickups

26. XP Orb `24×24` → `assets/placeholders/pickups/xp_orb.png`
27. Weapon Pickup (generic car-part shape) `24×24` → `assets/placeholders/pickups/weapon_pickup.png`
28. Health Pickup `24×24` → `assets/placeholders/pickups/health_pickup.png`

---

## Phase 6: Level-Up Card UI

### XP Bar

29. XP bar background / frame (full-width strip, fits at bottom or top of screen)
30. XP bar fill segment `16×8` → `assets/placeholders/ui/xp_bar_segment.png`

### Level-Up Cards

Cards appear as a selection overlay when a player levels up. Template is `64×96`.

31. Card frame — Weapon Unlock (weapon-themed border style) `64×96`
32. Card frame — Weapon Upgrade (upgrade/level-up border style) `64×96`
33. Card frame — Element Upgrade (Fire / Ice / Earth border style) `64×96`
34. Card frame — Stat Boost (general/neutral border style) `64×96`
35. Card highlight / selection glow overlay (applied on hover)

### Stat Boost Icons (used inside cards)

36. Speed boost icon `24×24`
37. Max HP boost icon `24×24`
38. Damage boost icon `24×24`
39. Cooldown reduction icon `24×24`

---

## Phase 7: CARIAD HUD Panel

The HUD panel sits on the right side of the screen and contains 6 car-feature indicator boxes. Each lights up and fades out (~3 s) when its trigger fires.

40. HUD panel background / frame (fixed right-side panel, fits 6 indicator boxes)
41. Indicator icon — **AC ❄️ COLD** (triggers on Ice element ability) `48×24`
42. Indicator icon — **ENGINE 🔥 OVERHEAT** (triggers on Fire element ability) `48×24`
43. Indicator icon — **SEAT MASSAGE 🌿 ACTIVE** (triggers on Earth healing ability) `48×24`
44. Indicator icon — **SUSPENSION ⚡ IMPACT** (triggers when player takes a significant hit) `48×24`
45. Indicator icon — **LIDAR 🔴 OBJECT DETECTED** (triggers on enemy spawn in current room) `48×24`
46. Indicator icon — **V2X 📡 SIGNAL SENT** (triggers at random intervals) `48×24`
47. Indicator lit / active state variant for each of the 6 icons (can be a color overlay or separate sprite)

### Loop Timer UI

48. Loop timer display frame / widget (shows 15-minute countdown, positioned top-left or top-center)
49. Loop counter label widget ("Loop 1", "Loop 2", …)

---

## Phase 8: Boss, Rooms & Mob Variants

### Boss Enemy

50. Boss — main sprite `96×96` or larger (must feel imposing relative to 32×32 enemies)
51. Boss — damaged / phase 2 variant (if applicable)
52. Boss attack effect sprite (projectile or AoE visual, 2–3 variants)
53. Boss defeat / death animation frame(s)

### Mob Swarm Variants (3–5 unique types, used in waves)

54. Mob variant A `32×32`
55. Mob variant B `32×32`
56. Mob variant C `32×32`
57. Mob variant D `32×32` *(optional)*
58. Mob variant E `32×32` *(optional)*

### Room Tilesets

59. Room 2 (Bamberg Altstadt) — floor tile `32×32` (corridor aesthetic)
60. Room 2 — wall tile `32×32`
61. Room 2 — obstacle / hazard sprite (spikes, traps, or environmental prop)
62. Room 3 (Burg Altenburg) — floor tile `32×32` (boss arena aesthetic)
63. Room 3 — wall tile `32×32`
64. Room 3 — boss altar / spawn platform sprite

### Shared Tileset (Room 1 and general)

65. Wall tile `32×32` → `assets/placeholders/walls/wall_tile.png`
66. Wall corner tile `32×32` → `assets/placeholders/walls/wall_corner.png`
67. Floor tile `32×32` → `assets/placeholders/backgrounds/floor_tile.png`
68. Room border / trim `32×32` → `assets/placeholders/backgrounds/room_border.png`

---

## Polish Pass (Phase 6+ — after core gameplay is locked)

### Animations (spritesheet or individual frames)

For each animated entity, frames needed: idle (1–4), walk (4–8), attack (2–4), death (2–4).

69. Tank — all animation frames (3 stages × 4 animation types = 12 sets)
70. Speedster — all animation frames (12 sets)
71. Engineer — all animation frames (12 sets)
72. Basic Enemy — all animation frames (4 sets)
73. Fast Enemy — all animation frames (4 sets)
74. Tank Enemy — all animation frames (4 sets)
75. Boss — all animation frames (idle, attack phase 1, attack phase 2, death)

### Special Animations

76. Player downed state (grayscale or visual indicator that player is knocked down)
77. Stage evolution / transformation transition effect (car → Proto-Bot → AutoBot)
78. Level-up card selection animation (highlight / flip / zoom-in)
79. HUD indicator flash / pulse animation cycle (2–3 frames per indicator)

### Screens & Menus

80. Lobby screen background / layout
81. Game Over screen background / layout
82. In-game pause menu overlay (if applicable)
83. Victory / loop-complete screen

---

## Audio (no audio implemented yet — complete pass needed)

84. Background music — Room 1 loop
85. Background music — Room 2 loop
86. Background music — Room 3 / boss arena loop
87. SFX — player bullet fire
88. SFX — enemy bullet fire
89. SFX — Exhaust Flames activation
90. SFX — Spinning Tires activation
91. SFX — Antenna Beam activation
92. SFX — Horn Shockwave activation
93. SFX — Airbag Shield activation
94. SFX — enemy hit
95. SFX — enemy death
96. SFX — player hit
97. SFX — player downed
98. SFX — level-up / card selection
99. SFX — XP pickup
100. SFX — weapon pickup
101. SFX — HUD indicator chime (1 per indicator, 6 distinct sounds)
102. SFX — loop timer warning (last 60 seconds)
103. SFX — boss spawn
104. SFX — boss death
