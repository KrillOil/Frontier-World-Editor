# First MVP Contract

## Completion statement

The first MVP is complete when the Creator can open Crimsdale, define a reusable object inside the editor, place and adjust instances of it, save the authored package, reopen it without loss, and launch Frontier directly into that saved world.

This is one vertical authoring loop, not a collection of disconnected prototypes.

## Creator walkthrough

The acceptance demonstration is:

1. Open the Crimsdale package.
2. Navigate the world and select the existing fountain.
3. Inspect its definition and transform.
4. Open the Object Editor.
5. Duplicate `Crimsdale House A` into a new definition, name it, and choose its preview/runtime scene.
6. Return to the World workspace and find the new definition in the palette without restarting.
7. Place three instances with ground preview and rotation.
8. Move one, rotate one, and delete one; undo and redo the deletion.
9. Place or adjust `player_start`.
10. Save, close, reopen, and observe the same definitions and composition.
11. Press **Test World**.
12. Frontier opens the saved Crimsdale package at `player_start`.

Any step that requires hand-editing JSON or Godot scenes fails the MVP.

## Application shape

The application has two workspaces sharing one in-memory authored package.

### World workspace

```text
┌──────────────────────────────────────────────────────────────┐
│ File  Edit  View  Object Editor              ▶ Test World   │
├──────────────┬───────────────────────────────┬───────────────┤
│ Palette      │ World viewport                │ Inspector     │
│ Search       │                               │ Identity      │
│ Categories   │ Select/place/move/rotate      │ Transform     │
│ Definitions  │                               │ Definition    │
├──────────────┴───────────────────────────────┴───────────────┤
│ Tool/status message                         Unsaved changes │
└──────────────────────────────────────────────────────────────┘
```

The viewport remains primary. Palette choice enters placement; selection returns to selection mode. Escape cancels the current transient interaction before it clears selection.

### Object Editor workspace

```text
┌──────────────────────────────────────────────────────────────┐
│ Back to World   New   Duplicate   Delete                     │
├───────────────────┬──────────────────────────────────────────┤
│ Search/categories │ Definition fields                        │
│ Definition list   │ ID (fixed after creation)                │
│                   │ Display name / category / scene path      │
└───────────────────┴──────────────────────────────────────────┘
```

Version 1 edits only fields in `definitions.schema.json`. It is not a generic property editor. A definition ID becomes immutable after creation; duplication is the safe way to create a variant.

## Core interaction rules

- Left click selects or places according to the active tool.
- Escape cancels placement or manipulation first; a second Escape may clear selection.
- A placement ghost is visibly non-final and never enters authored data.
- Placement and movement project to the authored ground surface.
- Rotation uses degrees and supports both a visual control and numeric entry.
- Delete, create, place, move, rotate, and field edits participate in undo/redo.
- Unsaved changes are always visible.
- Closing, opening another package, or testing with unsaved changes presents Save, Discard, and Cancel.
- Errors name the file or object identity and the failed field or reference.

Exact mouse bindings and visual styling may be refined through use, but these behavioral rules are fixed for the MVP.

## Definition lifecycle

Create requires a unique stable ID, display name, category, and scene path. The editor validates before adding it.

Duplicate copies editable fields, requires a new ID, and does not copy placed instances.

Changing display name, category, or scene path updates the palette and all previews referencing that definition. It does not rewrite instance records.

Delete is blocked while instances reference the definition. The error identifies the reference count and offers to select affected instances. Cascading deletion is outside the MVP.

Unknown or unloadable scenes display an identified placeholder. The package may be inspected, but it cannot be saved or tested as valid until the error is resolved.

## World package lifecycle

There is one open package at a time.

```text
disk JSON -> parse -> structural validation -> reference validation
          -> in-memory authored package -> editor commands
          -> validation -> deterministic atomic save -> disk JSON
```

- Failed open leaves the current valid package untouched.
- Save writes temporary files, validates them, then replaces the package files.
- A failed save leaves the last valid files intact and keeps the editor dirty.
- Save ordering follows `AUTHORING_MODEL.md`.
- Scene resources are referenced; they are not copied or imported by the MVP.

## Runtime separation

The editor owns definition and composition data. It may instantiate scenes for authoring preview, but it must not simulate Frontier gameplay.

Frontier receives only the saved package path, requested spawn, and agreed development-launch options. Test World never relies on unsaved in-memory state or shared repository source.

## Required user-facing states

The application must have explicit states for:

- no package open;
- loading;
- ready and clean;
- ready with unsaved changes;
- placement active;
- invalid package or unresolved resource;
- saving;
- launching Frontier;
- Frontier launch failure.

Long work reports progress. Errors remain visible until dismissed or resolved; status text alone is not sufficient for destructive or blocking failures.

## Verification strategy

Automated checks cover schemas, reference integrity, command undo/redo, deterministic serialization, atomic-save failure, and semantic round trips.

Godot integration tests cover workspace construction, package-to-preview mapping, selection, placement state, palette refresh after definition edits, and launch command construction.

The Creator walkthrough above is the final manual acceptance test using Crimsdale and Frontier.

## MVP boundaries

Included:

- one open package;
- buildings, props, landmarks, and units as definition categories;
- basic definition CRUD within the version 1 schema;
- placed-instance composition;
- one reserved player start;
- deterministic persistence;
- Frontier Test World launch.

Excluded:

- terrain authoring;
- gameplay fields, inheritance, abilities, items, buffs, or arbitrary properties;
- triggers, regions, factions, scenarios, campaigns, and scripting;
- asset importing or packaging;
- collaborative editing, mod publishing, and runtime gameplay simulation.

## Milestone sequence

1. M01 — Project Foundation
2. M02 — Crimsdale Viewport
3. M03 — Selection and Inspection
4. M04 — Object Definitions
5. M05 — Object Placement and Transform
6. M06 — Deterministic Save and Load
7. M07 — Test World Integration

Each milestone must leave the application demonstrable. M07 completes the MVP; later capabilities require a new commission.

