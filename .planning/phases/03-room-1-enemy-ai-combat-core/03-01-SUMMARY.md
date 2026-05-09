---
phase: 03-room-1-enemy-ai-combat-core
plan: "01"
subsystem: room-geometry
tags: [navmesh, spawn-points, obstacle, room1]
dependency_graph:
  requires: []
  provides: [central-obstacle, enemy-spawn-points, navmesh-ready-geometry]
  affects: [03-02, 03-05]
tech_stack:
  added: []
  patterns: [StaticBody2D-placeholder-collider, Marker2D-spawn-points]
key_files:
  created: []
  modified:
    - scenes/Game.tscn
decisions:
  - "D-03: Rectangular placeholder collider for central obstacle (StaticBody2D + RectangleShape2D 80x80)"
  - "D-04: Navmesh spike — ObstacleCenter uses collision_layer=1 to register as navmesh hole"
  - "D-19: Five fixed enemy spawn points at room corners and top-center"
metrics:
  duration: "~1 minute"
  completed: "2026-05-09"
  tasks_completed: 1
  tasks_total: 2
---

# Phase 3 Plan 01: Navmesh Spike — Room 1 Obstacle & Spawn Points — Summary

**One-liner:** Room1 geometry finalized with 80x80 central obstacle (collision_layer=1) and 5 enemy spawn markers at room edges, ready for NavigationPolygon bake.

---

## Status

**Complete** — Task 1 and Task 2 both verified. Navmesh baked with wall holes and central obstacle hole confirmed by human (resume signal: navmesh-ok).

---

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Add central obstacle and enemy spawn points to Game.tscn | 67ee1db | scenes/Game.tscn |
| 2 | Navmesh spike — bake NavigationPolygon and verify enemy pathfinding | human | scenes/Game.tscn (baked) |

---

## Task 2 — Verified

**Type:** checkpoint:human-verify  
**Gate:** blocking — Phase 3 Wave 2 plans (03-02, 03-03) cannot start until navmesh is confirmed working.

See checkpoint details below for exact baking steps.

---

## What Was Built

### ObstacleCenter (StaticBody2D)
- **Position:** Vector2(400, 300) — room center
- **Collision layer:** 1 (world) — same as perimeter walls, so NavigationPolygon parsed_geometry_type=STATIC_COLLIDERS will pick it up as a navmesh hole
- **Shape:** RectangleShape2D 80×80 px
- **Visual:** Polygon2D with vertices ±40 gray rectangle

### EnemySpawnPoints (Node2D)
Five Marker2D children spread around the room edges and top-center:
| Name | Position |
|------|----------|
| ESpawn1 | (100, 100) — top-left corner |
| ESpawn2 | (700, 100) — top-right corner |
| ESpawn3 | (100, 500) — bottom-left corner |
| ESpawn4 | (700, 500) — bottom-right corner |
| ESpawn5 | (400, 150) — top-center |

### NavigationPolygon (existing)
- `NavigationRegion2D` already present in scene with empty `NavigationPolygon_1` sub_resource
- Must be configured and baked by human in Godot editor (Task 2)

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

- `NavigationPolygon_1` sub_resource is empty (no polygon data). This is intentional — the polygon must be drawn and baked in the Godot editor by a human (D-04 spike requirement). This stub is resolved by the Task 2 checkpoint verification.

---

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Scene geometry additions only.

---

## Self-Check

- [x] scenes/Game.tscn modified with ObstacleCenter and EnemySpawnPoints
- [x] Commit 67ee1db exists with correct content
- [x] EnemySpawnPoints node present with 5 Marker2D children
- [x] ObstacleCenter has collision_layer=1 and RectangleShape2D_obs collider

## Self-Check: PASSED
