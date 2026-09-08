# GitHub Milestones and Issues

Create these as GitHub milestones. Issue titles and bodies below are intentionally concise; acceptance criteria are the implementation contract.

## M01 — Project Foundation

Outcome: a deterministic Godot 4.7.1 editor shell can be opened and verified.

### Issue: Establish the Godot 4.7.1 editor project

Acceptance:

- [ ] `project.godot` declares a Godot 4.7.1-compatible project.
- [ ] The app opens into an empty three-pane editor shell: palette, viewport, inspector.
- [ ] A documented command runs the app from a clean checkout.
- [ ] A documented command runs automated tests headlessly.
- [ ] No world editing behavior is included.

### Issue: Implement authored-package validation fixtures

Acceptance:

- [ ] Both JSON schemas and the Crimsdale fixtures validate in automation.
- [ ] Duplicate IDs and unresolved `definition_id` references fail with actionable messages.
- [ ] Unsupported `format_version` fails explicitly.

## M02 — Crimsdale Viewport

Outcome: the Creator can open and navigate the reference world.

### Issue: Load the Crimsdale reference package into the viewport

- [ ] Definitions resolve to preview scenes through one registry boundary.
- [ ] Every fixture object appears at its persisted transform.
- [ ] Missing scenes produce an identified placeholder and error, not silent omission.

### Issue: Add WC3-style viewport navigation

- [ ] Pan, orbit/rotate, and zoom are available without entering a modal tool.
- [ ] Controls and reset-view behavior are documented in the UI.
- [ ] A repeatable manual check covers navigation in Crimsdale.

## M03 — Selection and Inspection

Outcome: existing objects can be selected and understood.

### Issue: Select and highlight a placed object

- [ ] Clicking a visible object selects exactly one instance.
- [ ] Empty-space click clears selection.
- [ ] Highlighting does not modify authored data.

### Issue: Inspect identity and transform

- [ ] Inspector shows instance ID, definition ID, display name, position, and yaw.
- [ ] Values reflect the canonical authored model.
- [ ] Editing remains out of scope for this issue.

## M04 — Object Placement and Transform

Outcome: the Creator can compose a settlement using editor-owned definitions.

### Issue: Browse definitions in the object palette

- [ ] Palette groups v1 definitions by category.
- [ ] It displays definition names and stable IDs.
- [ ] Selecting a definition enters placement mode.

### Issue: Preview, rotate, place, and cancel an object

- [ ] A non-persisted ghost follows the ground under the cursor.
- [ ] Rotation is adjustable before placement.
- [ ] Click creates one instance with a stable ID; Escape cancels.
- [ ] No preview state enters saved data.

### Issue: Move, rotate, and delete a selected object

- [ ] Visual controls update canonical position or yaw.
- [ ] Numeric inspector fields support precise edits.
- [ ] Delete removes only the selected instance and supports confirmation/undo as decided during implementation.

### Issue: Place and edit the player start

- [ ] The Creator can place one `player_start`.
- [ ] Position and yaw are editable.
- [ ] Duplicate reserved starts are prevented with an actionable message.

## M05 — Deterministic Save and Load

Outcome: authored work survives closing and reopening without semantic drift.

### Issue: Save a validated deterministic world package

- [ ] Save rejects invalid state before replacing valid files.
- [ ] Output ordering follows `docs/AUTHORING_MODEL.md`.
- [ ] Saving unchanged content produces no semantic or ordering diff.

### Issue: Verify semantic round trips

- [ ] Automated tests cover definitions, instances, transforms, and spawn points.
- [ ] Open → save → reopen preserves all authored meaning.
- [ ] Malformed packages report file and field context.

## M06 — Test World Integration

Outcome: **Test World** launches Frontier directly into the saved Crimsdale composition.

### Issue: Agree and document the Frontier launch contract

- [ ] The Frontier repository owner/agent confirms package and spawn arguments.
- [ ] Supported package version behavior is defined on both sides.
- [ ] Failure and exit behavior is testable.

### Issue: Implement Test World

- [ ] Test validates and saves before launch.
- [ ] Frontier receives the package path and `player_start` explicitly.
- [ ] Frontier opens the edited composition without ordinary player menus.
- [ ] Validation, launch, and runtime-load failures are visible in the editor.

