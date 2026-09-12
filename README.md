# Frontier World Editor

A standalone Godot 4.7.1 authoring application for Frontier, inspired by the Warcraft III World Editor.

The editor owns reusable object definitions and map composition. Frontier consumes exported authored data. The first commissioned slice is a Crimsdale-based world-composition loop: open, navigate, select, place, transform, delete, save, and eventually **Test World** in Frontier.

Build the guided-mission MVP through the UI with [the Creator tutorial](docs/CREATOR_TUTORIAL.md), then use [the review checklist](docs/CREATOR_REVIEW.md).

## Start here

- Agents: read [`AGENTS.md`](AGENTS.md), then take one ready GitHub issue.
- Creator: use issues and milestones to approve scope and verify outcomes.
- Product boundaries: [`docs/SCOPE.md`](docs/SCOPE.md)
- Complete first MVP: [`docs/MVP.md`](docs/MVP.md)
- Review the current MVP: [`docs/REVIEW.md`](docs/REVIEW.md)
- Authored data: [`docs/AUTHORING_MODEL.md`](docs/AUTHORING_MODEL.md)
- Playable units: [`docs/PLAYABLE_UNITS.md`](docs/PLAYABLE_UNITS.md)
- Terrain delivery contract: [`docs/TERRAIN_CAPABILITY.md`](docs/TERRAIN_CAPABILITY.md)
- Frontier handoff: [`docs/FRONTIER_INTEGRATION.md`](docs/FRONTIER_INTEGRATION.md)

Implementation is proceeding through the accepted GitHub milestones, beginning with project foundation.

## Run the project

Godot 4.7.1 is required.

```bash
./scripts/run.sh
```

If Godot is not named `godot` on your system:

```bash
GODOT_BIN=/path/to/godot ./scripts/run.sh
```

## Run automated checks

```bash
./scripts/test.sh
```

The test command verifies the exact Godot version and runs the shell checks headlessly.

## MVP controls

- Middle-drag: orbit camera
- Shift + middle-drag: pan camera
- Mouse wheel: zoom
- Left click: select or place
- `Q` / `E`: rotate placement preview
- `G`: move the selected instance, then click its destination
- `Escape`: cancel move or placement
- Inspector: precise position and yaw editing
- Object Editor: create, duplicate, edit, and safely delete definitions
- Unit definitions: author ownership, health, movement, selection, and basic combat values
- Terrain: create an 8–512-cell base grid, edit bounds with a nine-point anchor, reset through an impact confirmation, and undo or redo structural changes
- Terrain Workflow: press `S` and drag an inclusive source rectangle, `Ctrl+C` to copy, `Ctrl+V` to preview Paste, or choose **Preview Move**; move the live snapped ghost, press `Enter` to confirm one Undo entry, or `Escape` to cancel without mutation; press `F` then click terrain for a detailed sample
- Creator palette: switch between Terrain, Units, Props, Regions, and Mission inside the workspace; dock, resize, or collapse it without changing authored data
- Sculpt: choose Raise, Lower, Flatten, Smooth, Plateau, or Noise; tune radius/strength/falloff in the viewport HUD; drag to apply one undoable stroke; press `Escape` before release to cancel
- Surfaces: browse the Crimsdale texture palette, manage up to four portable layers, and paint or erase normalized blends with live viewport feedback
- Cliffs & Water: raise/lower discrete cliff cells, author traversable ramp edges, replace cliff style, and preview global shallow/deep water with derived shores
- Pathing: toggle the reason-coded walkability overlay, paint/erase movement or placement blocks, inspect three clearance sizes, and validate starts and isolated areas
- Environment: author focused sun, ambient, fog, and portable sky settings; toggle the Godot 4.7.1 parity preview independently of saved data
- Scenario: create portable mission metadata and author labeled point, rectangle, and path regions directly against the world

For interactive review, choose **Test Setup…** and select either an exported Frontier executable or Godot 4.7.1 plus Frontier's `Game` folder. Automated environments may set `FRONTIER_EXECUTABLE` and, for source review, `FRONTIER_PROJECT_PATH`. Both routes use the accepted `--world-package <path> --spawn player_start` contract.
