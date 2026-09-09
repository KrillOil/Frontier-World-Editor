# Frontier Integration Boundary

## Contract

```text
Frontier World Editor -> authored world package -> Frontier runtime
```

The repositories remain independent. Integration occurs through a versioned package and an explicit launch command, not shared scenes, source folders, or editor-only runtime behavior.

## Test World launch contract

```text
Frontier --world-package <absolute-package-directory> --spawn <spawn_id>
```

The initial workflow uses `player_start`. When launching Frontier's Godot project during development, the editor inserts Godot's `--path <Frontier/Game> --` prefix before the same runtime arguments.

**Test World** must:

1. Validate and save the current package.
2. Invoke a configured Frontier executable or development launch command.
3. Pass the package path and requested spawn `player_start` explicitly.
4. Surface launch or validation failures in the editor.
5. Launch Frontier directly into the edited world, bypassing ordinary menus intended for players.

Configure `FRONTIER_EXECUTABLE` with the exported Frontier executable. For source-project review, set it to the Godot 4.7.1 executable and also set `FRONTIER_PROJECT_PATH` to Frontier's `Game` directory.

## Compatibility

- The package `format_version` is the compatibility boundary.
- Both producer and consumer reject unsupported required versions.
- Frontier must never silently skip unresolved definitions or placed instances.
- Editor preview code must not become a second gameplay implementation.
