# Frontier Integration Boundary

## Contract

```text
Frontier World Editor -> authored world package -> Frontier runtime
```

The repositories remain independent. Integration occurs through a versioned package and an explicit launch command, not shared scenes, source folders, or editor-only runtime behavior.

## Test World target

When commissioned, **Test World** must:

1. Validate and save the current package.
2. Invoke a configured Frontier executable or development launch command.
3. Pass the package path and requested spawn `player_start` explicitly.
4. Surface launch or validation failures in the editor.
5. Launch Frontier directly into the edited world, bypassing ordinary menus intended for players.

The exact command-line argument names must be agreed with the Frontier repository during the integration issue. Until then, do not invent a permanent CLI contract.

## Compatibility

- The package `format_version` is the compatibility boundary.
- Both producer and consumer reject unsupported required versions.
- Frontier must never silently skip unresolved definitions or placed instances.
- Editor preview code must not become a second gameplay implementation.

