# MVP Review

## Start

Open the repository in Godot 4.7.1 and run the project, or use:

```bash
GODOT_BIN=/path/to/Godot_v4.7.1-stable_linux.x86_64 ./scripts/run.sh
```

The editor opens Crimsdale automatically. It uses deliberately simple reference geometry so the authoring workflow can be judged independently of production art.

## Review path

1. Orbit with middle-drag, pan with Shift + middle-drag, and zoom with the wheel.
2. Click the house or fountain and inspect its identity and transform.
3. Use `G`, then click the ground to move the selection. Use Undo and Redo.
4. Select a definition in the palette. Move the cursor over the viewport, rotate with `Q`/`E`, click to place, and press Escape to stop.
5. Open **Object Editor**, select `Crimsdale House A`, and choose Duplicate.
6. Review or replace the suggested stable ID, then choose **Create Definition**.
7. Change its display name or category and apply. Return to the world and confirm the palette updated.
8. Try deleting a definition used by placed instances. Confirm deletion is blocked with a reference count.
9. Save, close, reopen, and confirm the authored state remains.

## Test World

Test World is operational through a configurable command while Frontier's permanent command-line contract remains unconfirmed.

```bash
FRONTIER_TEST_COMMAND='frontier --world-package "{package}" --spawn "{spawn}"' ./scripts/run.sh
```

The editor substitutes the absolute package directory and `player_start`, saves first, and reports launch failure in the status bar.

## Known integration dependency

The editor-side MVP is reviewable. Completing the live Frontier launch requires the Frontier repository to accept a package path and spawn identifier. That cross-repository contract remains represented by GitHub issue #13 and must not be guessed here.

## Automated evidence

```bash
./scripts/test.sh
```

The checks cover the shell, authored-data validation, duplicate and unresolved references, unsupported versions, command undo/redo, deterministic save/reopen, and package-to-workspace integration.
