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

## M04 — Object Definitions

Outcome: the Creator can define reusable content inside the editor and use it immediately.

### Issue: Browse definitions in the Object Editor and palette

- [ ] Both workspaces group v1 definitions by category and support search.
- [ ] They display definition names and stable IDs.
- [ ] Changes in the Object Editor update the palette without restarting.

### Issue: Create and duplicate a basic object definition

- [ ] Creation requires every field in `definitions.schema.json`.
- [ ] IDs are validated for format and uniqueness before creation.
- [ ] Duplicate copies editable fields but requires a new ID.
- [ ] New definitions participate in undo/redo and mark the package dirty.

### Issue: Edit and safely delete a basic object definition

- [ ] Display name, category, and scene path can be edited; ID is immutable.
- [ ] Referencing previews and palette entries update immediately.
- [ ] Delete is blocked while instances reference the definition and identifies affected instances.
- [ ] Definition edits and deletion participate in undo/redo.

## M05 — Object Placement and Transform

Outcome: the Creator can compose a settlement using editor-owned definitions.

### Issue: Preview, rotate, place, and cancel an object

- [ ] A non-persisted ghost follows the ground under the cursor.
- [ ] Rotation is adjustable before placement.
- [ ] Click creates one instance with a stable ID; Escape cancels.
- [ ] No preview state enters saved data.

### Issue: Move, rotate, and delete a selected object

- [ ] Visual controls update canonical position or yaw.
- [ ] Numeric inspector fields support precise edits.
- [ ] Delete removes only the selected instance.
- [ ] Place, move, rotate, and delete participate in undo/redo.

### Issue: Place and edit the player start

- [ ] The Creator can place one `player_start`.
- [ ] Position and yaw are editable.
- [ ] Duplicate reserved starts are prevented with an actionable message.

## M06 — Deterministic Save and Load

Outcome: authored work survives closing and reopening without semantic drift.

### Issue: Save a validated deterministic world package

- [ ] Save rejects invalid state before replacing valid files.
- [ ] Output ordering follows `docs/AUTHORING_MODEL.md`.
- [ ] Saving unchanged content produces no semantic or ordering diff.

### Issue: Track dirty state and guard package transitions

- [ ] Authored changes visibly mark the package dirty.
- [ ] Open, close, and Test World offer Save, Discard, and Cancel when dirty.
- [ ] Failed open leaves the current valid package untouched.
- [ ] Failed save preserves the last valid files and dirty state.

### Issue: Verify semantic round trips

- [ ] Automated tests cover definitions, instances, transforms, and spawn points.
- [ ] Open → save → reopen preserves all authored meaning.
- [ ] Malformed packages report file and field context.

## M07 — Test World Integration

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
