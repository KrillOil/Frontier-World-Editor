# Terrain Editor Capability

## Outcome

The Creator can build, revise, validate, and Test World a playable Crimsdale landscape without editing terrain data or Godot resources by hand.

The commissioned target contains exactly 47 features across eight implementation increments:

1. Terrain creation — 5
2. Sculpting — 7
3. Surface painting — 6
4. Cliffs and water — 6
5. Pathing — 5
6. Environment — 5
7. Editing workflow — 7
8. Persistence and Frontier runtime integration — 6

GitHub issues are the authoritative feature and acceptance-criteria inventory. Each increment must be independently reviewable and leave existing world composition and playable units working.

## Fixed boundaries

- Frontier World Editor owns canonical terrain authoring data.
- Frontier owns runtime mesh, collision, navigation, water, and environment interpretation.
- Integration remains package-based; repositories do not share source directories.
- Godot 4.7.1 remains pinned.
- Crimsdale is the reference and end-to-end acceptance world.
- Terrain operations participate in the existing dirty-state, undo/redo, deterministic save, reopen, and Test World workflow.
- Invalid or unsupported terrain data is rejected explicitly; it is never silently repaired or discarded.

## Review gates

Before implementation, review the proposed issues for:

- canonical height, surface, cliff, water, pathing, and environment representation;
- coordinate system, resolution, size limits, and resize semantics;
- deterministic serialization and format-version migration;
- undo memory and performance budgets;
- runtime mesh seams, collision, navigation rebuilds, and Test World latency;
- which operations must be non-destructive and which require confirmation.

Do not implement until the review findings are resolved into issue acceptance criteria and the first increment is explicitly commissioned.
