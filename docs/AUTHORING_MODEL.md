# Authoring Model v1

## Ownership

Frontier World Editor is the source of truth for authored content. A world package contains reusable definitions and placed instances that reference them. Frontier resolves and executes those definitions; it does not own individual authored objects.

## Package layout

```text
worlds/<world_id>/
├── definitions.json
├── world.json
├── terrain.json   (optional)
└── scenario.json  (optional)
```

The core composition files use `format_version: 1`; terrain and scenario use their named v1 version fields. All use UTF-8 JSON, stable identifiers, and deterministic ordering on save.

Terrain and scenario documents have independent version fields but participate in the same protected package save. A failed transaction restores all prior package files together.

## Definitions

Version 1 supports only the categories required for world composition:

- `building`
- `prop`
- `landmark`
- `unit`

Each definition contains:

- `definition_id`: stable, package-unique identifier
- `display_name`: Creator-facing label
- `category`: one of the values above
- `scene_path`: portable logical resource path interpreted by the editor and Frontier

Inheritance, base/custom variants, gameplay statistics, items, abilities, and arbitrary property bags are deferred. They require accepted schema changes.

## Placed instances

Each object contains:

- `instance_id`: stable and unique within the world
- `definition_id`: reference to a definition in the package
- `position`: `[x, y, z]` in Godot world coordinates
- `rotation_y`: yaw in degrees

Array order has no gameplay meaning. Saves order definitions by `definition_id`, objects by `instance_id`, and spawn points by `spawn_id` to keep diffs stable.

## Spawn points

Spawn points are authoring metadata, not visible object definitions. Version 1 supports a stable `spawn_id`, `position`, and `rotation_y`. The initial Test World workflow reserves `player_start`.

## Validation

Reject:

- unsupported `format_version` values;
- malformed identifiers;
- duplicate identifiers;
- unknown definition references;
- undocumented properties;
- missing required fields or invalid vector shapes.

Load → save → load must preserve authored meaning. Formatting is not meaningful; identities, references, membership, transforms, and spawn points are.

The executable contract is in [`schemas/`](../schemas/).
