#!/usr/bin/env python3
"""Generate simple colored PNG placeholder assets for the Roge-Like game.

Uses only built-in Python modules (struct, zlib) to create PNG files.
No external dependencies required.

Usage: python3 generate_placeholders.py [output_dir]
"""

import struct
import zlib
import os
import sys

def create_png(width, height, color, shape="rectangle", border_color=None, border_width=2):
    """Create a simple PNG with a colored shape.
    
    Args:
        width: Image width in pixels
        height: Image height in pixels
        color: RGB tuple (r, g, b)
        shape: "rectangle", "circle", or "rounded_rect"
        border_color: Optional RGB tuple for border
        border_width: Border width in pixels
    """
    # Create pixel data (RGBA)
    pixels = []
    for y in range(height):
        row = []
        for x in range(width):
            # Default to transparent
            r, g, b, a = 0, 0, 0, 0
            
            # Check if pixel is inside the shape
            cx, cy = width // 2, height // 2
            
            if shape == "rectangle":
                # Fill entire rectangle
                r, g, b, a = color[0], color[1], color[2], 255
            elif shape == "circle":
                # Draw a circle centered in the image
                radius = min(width, height) // 2 - 2
                dx, dy = x - cx, y - cy
                if dx*dx + dy*dy <= radius*radius:
                    r, g, b, a = color[0], color[1], color[2], 255
            elif shape == "rounded_rect":
                # Draw a rounded rectangle
                margin = 4
                rx1, ry1 = margin, margin
                rx2, ry2 = width - margin, height - margin
                corner_radius = 8
                
                # Check if inside the rounded rectangle
                if rx1 <= x <= rx2 and ry1 <= y <= ry2:
                    # Check corners
                    in_corner = True
                    if x < rx1 + corner_radius and y < ry1 + corner_radius:
                        # Top-left corner
                        dx, dy = x - (rx1 + corner_radius), y - (ry1 + corner_radius)
                        in_corner = dx*dx + dy*dy <= corner_radius*corner_radius
                    elif x > rx2 - corner_radius and y < ry1 + corner_radius:
                        # Top-right corner
                        dx, dy = x - (rx2 - corner_radius), y - (ry1 + corner_radius)
                        in_corner = dx*dx + dy*dy <= corner_radius*corner_radius
                    elif x < rx1 + corner_radius and y > ry2 - corner_radius:
                        # Bottom-left corner
                        dx, dy = x - (rx1 + corner_radius), y - (ry2 - corner_radius)
                        in_corner = dx*dx + dy*dy <= corner_radius*corner_radius
                    elif x > rx2 - corner_radius and y > ry2 - corner_radius:
                        # Bottom-right corner
                        dx, dy = x - (rx2 - corner_radius), y - (ry2 - corner_radius)
                        in_corner = dx*dx + dy*dy <= corner_radius*corner_radius
                    
                    if in_corner:
                        r, g, b, a = color[0], color[1], color[2], 255
            
            # Apply border if specified
            if border_color and a > 0:
                # Simple border: check if pixel is near the edge
                is_edge = (x < border_width or x >= width - border_width or 
                          y < border_width or y >= height - border_width)
                if is_edge:
                    r, g, b = border_color[0], border_color[1], border_color[2]
            
            row.extend([r, g, b, a])
        pixels.append(bytes([0] + row))  # 0 = filter type (None)
    
    # Combine all rows
    raw_data = b''.join(pixels)
    
    # Compress the data
    compressed = zlib.compress(raw_data, 9)
    
    # Build PNG file
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)  # 8-bit, RGBA
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data)
    ihdr_chunk = struct.pack('>I', len(ihdr_data)) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)
    
    # IDAT chunk
    idat_crc = zlib.crc32(b'IDAT' + compressed)
    idat_chunk = struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)
    
    # IEND chunk
    iend_crc = zlib.crc32(b'IEND')
    iend_chunk = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)
    
    return signature + ihdr_chunk + idat_chunk + iend_chunk


def main():
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/placeholders"
    
    assets = [
        # Players - colored circles (32x32)
        ("players/player_tank.png", 32, 32, (70, 130, 180), "circle"),      # Steel Blue
        ("players/player_speedster.png", 32, 32, (255, 165, 0), "circle"),   # Orange
        ("players/player_engineer.png", 32, 32, (50, 205, 50), "circle"),    # Lime Green
        
        # Walls - gray rectangles (32x32)
        ("walls/wall_tile.png", 32, 32, (128, 128, 128), "rectangle"),       # Gray
        ("walls/wall_corner.png", 32, 32, (100, 100, 100), "rectangle"),     # Dark Gray
        
        # Enemies - red shapes (32x32)
        ("enemies/basic_enemy.png", 32, 32, (220, 20, 60), "circle"),        # Crimson
        ("enemies/fast_enemy.png", 32, 32, (255, 69, 0), "rounded_rect"),    # Red-Orange
        ("enemies/tank_enemy.png", 32, 32, (139, 0, 0), "rectangle"),        # Dark Red
        
        # Pickups - yellow/green shapes (24x24)
        ("pickups/xp_orb.png", 24, 24, (255, 255, 0), "circle"),             # Yellow
        ("pickups/weapon_pickup.png", 24, 24, (255, 215, 0), "rounded_rect"), # Gold
        ("pickups/health_pickup.png", 24, 24, (0, 255, 0), "circle"),        # Green
        
        # Projectiles - small shapes (16x16)
        ("projectiles/player_bullet.png", 16, 16, (173, 216, 230), "circle"), # Light Blue
        ("projectiles/enemy_bullet.png", 16, 16, (255, 99, 71), "circle"),    # Tomato
        
        # UI elements
        ("ui/hud_indicator.png", 48, 24, (64, 64, 64), "rounded_rect"),       # Dark Gray
        ("ui/xp_bar_segment.png", 16, 8, (100, 149, 237), "rectangle"),       # Cornflower Blue
        ("ui/card_placeholder.png", 64, 96, (211, 211, 211), "rounded_rect"), # Light Gray
        
        # Backgrounds
        ("backgrounds/floor_tile.png", 32, 32, (245, 245, 220), "rectangle"), # Beige
        ("backgrounds/room_border.png", 32, 32, (169, 169, 169), "rectangle"), # Dark Gray
    ]
    
    created_files = []
    for filepath, width, height, color, shape in assets:
        full_path = os.path.join(output_dir, filepath)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        
        png_data = create_png(width, height, color, shape)
        with open(full_path, 'wb') as f:
            f.write(png_data)
        created_files.append(filepath)
        print(f"  Created: {filepath} ({width}x{height}, {shape}, RGB{color})")
    
    print(f"\nTotal assets created: {len(created_files)}")
    
    # Create a README documenting the placeholder structure
    readme_path = os.path.join(output_dir, "README.md")
    readme_content = """# Placeholder Assets

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
"""
    
    with open(readme_path, 'w') as f:
        f.write(readme_content)
    print(f"  Created: README.md")
    
    # Create a .gdignore to prevent Godot from importing these as assets
    gdignore_path = os.path.join(output_dir, ".gdignore")
    with open(gdignore_path, 'w') as f:
        f.write("# Ignore placeholder assets during development\n")
        f.write("# Remove this file when final assets are added\n")
    print(f"  Created: .gdignore")


if __name__ == "__main__":
    main()
