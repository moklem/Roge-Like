# Placeholder Assets

## Overview

These are temporary placeholder assets for the Roge-Like game. All assets are simple colored shapes (PNG files) that will be replaced with final art before Phase 6.

## Directory Structure

```
assets/placeholders/
├── players/          # Player character sprites (32x32 circles)
├── walls/            # Wall and collision tiles (32x32 rectangles)
├── enemies/          # Enemy sprites (32x32 shapes)
├── pickups/          # XP orbs, weapon pickups, health (24x24 shapes)
├── projectiles/      # Bullet and projectile sprites (16x16 circles)
├── ui/               # HUD elements, XP bar segments, cards
└── backgrounds/      # Floor tiles, room borders (32x32 rectangles)
```

## Naming Convention

- **Format:** `{category}/{description}.png`
- **Player sprites:** `player_{role}.png` (e.g., `player_tank.png`)
- **Enemy sprites:** `{type}_enemy.png` (e.g., `basic_enemy.png`)
- **Pickups:** `{type}_pickup.png` or `{type}_orb.png`
- **Projectiles:** `{owner}_{type}.png` (e.g., `player_bullet.png`)

## Asset Swap Guide

To replace placeholders with final assets:

1. Create final art at the same dimensions as the placeholder
2. Use the same filename and place in the same directory
3. Update the scene files to reference the new asset path (or keep the same path)
4. Remove the placeholder file

**Note:** All assets are referenced via `preload()` in Godot scripts, so replacing the file at the same path will automatically use the new art.

## Asset Specifications

| Category | Size | Shape | Color | Purpose |
|----------|------|-------|-------|---------|
| Players | 32x32 | Circle | Role-specific | Player character sprites |
| Walls | 32x32 | Rectangle | Gray | Room geometry tiles |
| Enemies | 32x32 | Various | Red tones | Enemy character sprites |
| Pickups | 24x24 | Circle/Rect | Yellow/Green | Collectible items |
| Projectiles | 16x16 | Circle | Blue/Red | Weapon projectiles |
| UI | Various | Rounded Rect | Gray/Blue | HUD indicators |
| Backgrounds | 32x32 | Rectangle | Beige/Gray | Floor and borders |

## Milestone

**Before Phase 6:** All placeholders should be replaced with final assets.
