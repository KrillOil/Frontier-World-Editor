# Initial Scope

## Product outcome

The Creator can visually compose a small Crimsdale world without editing Godot scenes, coordinates, or serialized data by hand.

## Commissioned capabilities

The initial sequence must enable:

1. Open the editor into a world workspace.
2. Navigate a known Crimsdale reference world.
3. Select an existing placed object and inspect its identity and transform.
4. Choose an editor-owned definition from a palette.
5. Preview and place an instance on the ground.
6. Move, rotate, and delete a selected instance.
7. Save and reopen with no semantic data loss.
8. Define and place `player_start`.
9. Launch Frontier through **Test World** and observe the saved composition.

## Required workflow character

- The world viewport is the primary workspace.
- Placement is direct: choose definition, preview under cursor, click to place, rotate, Escape to cancel.
- Numeric editing supports precision but does not replace visual manipulation.
- Missing definitions and invalid data produce actionable errors; they are never silently discarded.

## Explicitly deferred

- Terrain sculpting or painting
- Regions and triggers
- Abilities, buffs, quests, dialogue, AI authoring, and campaigns
- General-purpose scripting
- Mod distribution and multiplayer editing
- Production asset-import pipeline
- Exact reproduction of Warcraft III UI or formats

Deferred work must not be added as architecture “for later” unless a commissioned issue needs an extension point now.

