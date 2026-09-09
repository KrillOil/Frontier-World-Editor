# Terrain Data Contract v1

This contract is accepted for the terrain capability. It constrains both repositories before terrain tools are implemented.

## Package and versions

An authored package may add `terrain.json` beside `definitions.json` and `world.json`. Packages without it remain valid flat legacy worlds. `terrain_format_version` versions this document independently; v1 is the only accepted version. Unknown fields and future required versions are rejected.

Opening never rewrites or upgrades files. A future migration must preview changes, create a recoverable backup, write the whole package transactionally, and be deterministic and idempotent.

Canonical JSON is UTF-8, compact, newline terminated, recursively key-sorted, and contains finite integers or decimal numbers only. SHA-256 of these bytes identifies canonical terrain input. Meshes, materials, shores, effective pathing, collision, navigation, thumbnails, and build caches are derived and never authoritative package data.

## Coordinates and topology

| Decision | v1 rule |
|---|---|
| Axes | Godot right-handed coordinates: +X east, +Y up, +Z south |
| Origin | `origin_x_m`, `origin_z_m` name the inclusive north-west grid corner |
| Size | `width_cells` east-west cells and `depth_cells` north-south cells |
| Samples | `(width_cells + 1) × (depth_cells + 1)` shared height vertices |
| Ordering | Row-major north-to-south, then west-to-east: `z * (width + 1) + x` |
| Cell ownership | A cell owns its north-west sample; east/south boundary samples are shared |
| Cell size | Uniform metres; v1 permits 0.5, 1, 2, or 4; Crimsdale uses 1 |
| Heights | Signed integer centimetres relative to world Y=0; range -32768..32767 |
| Sampling | Bilinear interpolation of four corner samples, then centimetres to metres |
| Bounds | West/north inclusive; east/south inclusive only for height sampling, exclusive for cells |
| Runtime chunks | Derived 32×32-cell chunks; canonical data is one global grid with no duplicated borders |
| Other grids | Surface, cliff, and pathing entries are one per cell using `z * width + x` |

Minimum terrain is 8×8 cells, Crimsdale target is 128×128, and maximum is 512×512. Total decoded canonical terrain may not exceed 64 MiB.

## Authored domains

- `heights_cm`: one signed height per vertex.
- `surfaces`: one to four stable logical surface IDs and one unsigned 0–255 weight per active layer per cell. Weights sum to 255. Layer 0 is the base and receives erased or rounding remainder weight. Ordering defines shader slots; identity remains the logical ID.
- `cliff_levels`: one signed level per cell. Neighbors differ by at most one unless joined by a declared ramp edge. Cliff height is 200 cm per level and is added to sampled continuous height for presentation. `ramps` are authored traversable cardinal cell edges.
- `water`: an enabled global plane height in centimetres. Per-cell depth, shallow/deep classification, and shores are derived. Shallow is `(0, 100]` cm; deep is greater than 100 cm.
- `pathing`: separate movement and placement arrays. Values are `inherit` or `blocked`; v1 has no force-allow. Effective restrictions derive from authored blocks plus bounds, cliffs without ramps, water rules, and slope.
- `environment`: authored sun azimuth/elevation degrees, linear RGB colors, normalized energies, fog enable/color/density/start/end metres, and a portable `sky_id`.
- `attachments`: optional object or spawn identities with `absolute` or `grounded` mode and centimetre offset. Legacy targets default to `absolute`. Creating terrain offers a preview; the recommended migration is `grounded` with an offset calculated to preserve the existing world Y exactly.

Surface, cliff-style, and sky IDs resolve through separate editor and Frontier catalogs. Package data never uses repository-local resource paths for these identities. Missing IDs remain inspectable and block save/Test World.

## Editing and history

Terrain changes use 32×32-cell tile deltas containing exact before/after spans. One press-drag-release gesture is one transaction. Escape restores its complete before-state; a new accepted edit clears redo. The history budget is 256 MiB decoded delta data. Oldest transactions are evicted with a visible notice; if one operation exceeds the budget it is rejected before mutation. Dirty state compares the current transaction cursor with the last successful save marker.

### Sculpt equations

Sculpt gestures snapshot parameters on press and place stamps every `max(cell_size / 4, radius / 4)` metres along the world-space pointer path. A circular stamp uses normalized distance `d`. Falloff is constant `1`, linear `1-d`, or smooth `(1-d)^2 × (3-2(1-d))`, clamped to `[0,1]`.

- Raise/lower add/subtract `round(strength_cm × falloff)`.
- Flatten blends toward the entered or sampled target by `min(1, strength_percent / 100) × falloff`.
- Plateau has full influence through 65% of its radius, then the selected falloff across the outer 35%.
- Smooth blends toward a clamped-border 3×3 mean.
- Noise adds `round(strength_cm × falloff × noise(x,z,seed))`; version 1 uses the integer hash in `terrain_sculptor.gd` and yields `[-1,1]`.

Results are rounded and clamped to signed centimetres. Preview uses a private buffer; release commits one exact delta and Escape discards it.

### Surface painting

Surface identity is the stable `surface_id`, resolved through the world catalog. Catalog entries include display name, source SHA-256, source color space, UV scale, preview color, and Frontier material key. An unresolved active ID stays visible but blocks save and Test World.

Each cell has one to four ordered uint8 weights totaling exactly 255. Layer 0 is the non-removable base. Painting increases the selected layer by `round(255 × opacity × falloff)` and proportionally reduces other layers; integer division rounds down and remaining units are removed in stable layer order. Erase transfers weight to layer 0. Add initializes zero weight, replace preserves weights, reorder moves weights with stable IDs, and remove transfers its weight to layer 0. In-use replace/remove shows affected cell and total-weight counts before one atomic history transaction.

### Cliffs, ramps, water, and shores

Cliff levels are per-cell signed integers in `[-16,16]`; each level contributes exactly 200 cm above the continuous corner heights. Cardinal neighbors may differ by at most one unless their shared edge has an explicit ramp record. Sculpt tools never change cliff levels. Ramps are stable `{x,z,direction}` records, are traversable, and suppress the vertical barrier on that edge. Invalid topology is rejected rather than repaired. `style_id` changes presentation without changing topology.

Water is one optional horizontal plane at `level_cm`. Cell-center depth is the plane minus bilinear terrain height and the cell cliff contribution: `<=0` is dry, `(0,100]` cm is shallow, and `>100` cm is deep. Shores are algorithm-versioned derived east/south dry-to-wet edges in row-major order. They are regenerated rather than saved, so regeneration is seam-safe and idempotent.

Resize, reset, paste, layer lifecycle, pathing rebuild, and runtime build are previewed transactions. They report changed/cropped samples and affected objects/spawns, commit all canonical files or none, and respond to cancellation within 250 ms.

## Object and spawn grounding

`absolute` preserves authored world Y through every terrain operation and reports intersections. `grounded` evaluates terrain after each committed operation and applies `sampled_height + offset`. Resize/crop never silently removes an attachment or target. Reset, cliff changes, paste, and water changes include affected targets in their impact preview.

## Determinism and performance gates

Verification uses 8×8 minimum, 128×128 Crimsdale, and 512×512 maximum deterministic fixtures on GitHub-hosted Ubuntu four-core runners and the Creator's Windows target.

- Pointer-to-preview: ≤16 ms median and ≤33 ms p95 on the target fixture.
- Target gesture commit: ≤250 ms; maximum commit: ≤2 s with progress after 250 ms.
- Target save/load: ≤1 s each; maximum: ≤5 s each.
- History: ≤256 MiB; total editor terrain working set: ≤1.5 GiB at maximum size.
- Target Frontier cold terrain build: ≤3 s; maximum: ≤15 s.
- Warm cached Test World: ≤1.5 s target and ≤5 s maximum.
- Cancellation acknowledgement: ≤250 ms; no partial canonical mutation.

## Golden conformance

The tiny shared package is the first executable gate. Editor and Frontier must agree on document validity, canonical hash, boundary and interior sampled heights, cell indexing, surface sums, cliff/ramp validity, effective pathing reasons, water depth, environment values, and forward-version rejection before TER-I01 begins.
