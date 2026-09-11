# Scenario Data Contract v1

## Purpose

`scenario.json` stores portable authored mission intent. Frontier World Editor owns it; Frontier validates and executes it. Runtime timers, active event subscriptions, AI paths, visibility textures, UI nodes, and save-game state are derived and never written back.

## Determinism

- UTF-8 JSON with one trailing newline.
- IDs use `^[a-z][a-z0-9_]*$` and are unique within their collection.
- Saves sort regions, groups, objectives, tutorials, cinematics, and sequences by ID. Objective-step and sequence-step order is authored and meaningful.
- Coordinates use the terrain contract: +X east, +Y up, +Z south. Region points are world-space metres.
- Equal-frame events execute by sequence ID, then action index. A one-shot sequence can fire at most once.

## Authored collections

- Regions: point, rectangle, or path geometry.
- Unit groups: stable references to placed unit instance IDs.
- Objectives: main or optional, initially hidden or active, with ordered steps and optional checkpoint regions.
- Tutorials: reusable control guidance with viewport/world indicators, optional highlights, and optional sequence gates.
- Cinematics: ordered typed steps; v1 supports dialogue, camera, unit cue, and audio.
- Sequences: one event, typed conditions, and ordered actions.

## Supported events

`scenario_start`, `unit_enters_region`, `unit_died`, `objective_changed`, `sequence_completed`.

## Supported conditions

`objective_is`, `group_alive`, `group_owned_by`, `sequence_has_run`.

## Supported actions

`show_message`, `show_tutorial`, `set_objective`, `set_objective_step`, `set_ownership`, `order_group`, `set_encounter`, `grant_reward`, `play_cinematic`, `complete_scenario`.

Payload keys are strict and type-specific. References must resolve before save or Test World. Cycles through `sequence_completed` are rejected. Unsupported versions or vocabulary are errors, never ignored.

## Lifecycle

`scenario.json` participates in the world package's existing crash-recoverable multi-file transaction. Failed open or save preserves the last valid package. Test World diagnostics identify stage, scenario/sequence/action, cause, and recovery. Cancellation never commits partial scenario state.
