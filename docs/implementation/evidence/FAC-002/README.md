# Direction-Set Editor Evidence

## Task ID

`FAC-002`

## Status

IMPLEMENTED_UNVERIFIED. This task delivers the user-facing editor for standard
and custom direction sets. `QA-FAC-001` remains the independent verification
task for the complete facing-grid authoring workflow.

## Evidence

- `facing/facing_direction_set_editor.tscn` is a dockable control for choosing
  four-, eight-, sixteen-way, or custom directional grids.
- `facing/facing_direction_set_editor.gd` validates custom names, removes
  cells that no longer belong to the selected set, reports missing/assigned
  status, exposes a selected cell for the next assignment workflow, and marks
  the application dirty after a change.
- `app/shared_ui/main_window.gd` puts the editor in the reachable Facing Grid
  Directions panel.
- `tests/integration/test_facing_direction_editor.gd` covers standard/custom
  changes, pruning, invalid input, selected-cell status, and serialization.

## Scope Boundary

Asset assignment is `FAC-003`; filename/folder placement, slot exchange,
mirroring, preview, diagnostics, and pixel controls remain their own `FAC-*`
tasks. The existing runtime evaluator is not reclassified by this UI task.
