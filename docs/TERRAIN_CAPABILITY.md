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

Status: **not ready for execution** following the 10 September 2026 Astra review. TER-I01 remains uncommissioned.

Before implementation, review the proposed issues for:

- canonical height, surface, cliff, water, pathing, and environment representation;
- coordinate system, resolution, size limits, and resize semantics;
- deterministic serialization and format-version migration;
- undo memory and performance budgets;
- runtime mesh seams, collision, navigation rebuilds, and Test World latency;
- which operations must be non-destructive and which require confirmation.

The parent GitHub capability cannot leave this gate until it links accepted:

- canonical terrain schema and package layout;
- coordinate/topology and authored-versus-derived decision tables;
- v1 compatibility and migration behavior;
- delta-history design with a numeric memory budget;
- minimum, Crimsdale-target, and maximum fixtures with numeric performance budgets;
- object and spawn grounding policy;
- paired Frontier runtime issues and compatible revision;
- a tiny golden package that produces matching height and pathing probes in both repositories.

## Reviewed delivery order

1. Close the capability contract gate without implementing terrain tools.
2. Deliver terrain document, incremental persistence, and delta-history foundations.
3. Prove a tiny Frontier height/surface mesh consumer before brush formats harden.
4. Deliver sculpting and surfaces against the shared grid and brush contracts.
5. Deliver cliffs/water, then pathing; verify Frontier conformance after each domain.
6. Deliver environment authoring after its portable-resource and parity contract.
7. Complete cross-domain workflow, clipboard, minimap, and accessibility.
8. Complete migrations, crash recovery, runtime caches, and Crimsdale Test World conformance.

Do not implement until the review findings are resolved into issue acceptance criteria and the first increment is explicitly commissioned.

## Workflow contract

- Selection is a bounded cell-resolution rectangle; clipboard v1 uses a north-west anchor and an explicit boolean mask.
- Copy domains are height, surface, cliff, water, and pathing. Replace copies all enabled values; merge skips zero cliff levels and inherited pathing.
- Paste requires matching cell size, surface-layer order, and cliff style. Its preview reports clipping, and validation commits every domain together or none.
- Terrain history is capped at 256 MiB, groups each gesture into one entry, evicts oldest entries with a visible flag, refuses a single over-budget change, invalidates redo after a new edit, and compares revisions to the save marker for dirty state.
- Grid and height snapping default to one cell and 25 cm. Sampling reports all authored domains at the chosen cell.
- Workflow shortcuts are listed in the panel and suppressed while a text or numeric field has focus. Status always reports the current selection, snap, clipboard, or tool result.
