# Directional Mirroring Evidence

## Task ID

`FAC-006`

## Status

IMPLEMENTED_UNVERIFIED. The Facing Grid Directions panel exposes a mirror
dialog for source/destination selection, optional handed-slot exchange, and
explicit overwrite protection. Independent acceptance remains `QA-FAC-001`.

## Evidence

- `facing/facing_mirror_dialog.tscn` is opened from the reachable direction
  panel and operates on the panel’s currently bound grid.
- Existing destination cells cannot be overwritten until the user enables the
  dialog’s explicit overwrite control.
- `tests/integration/test_facing_direction_editor.gd` verifies blocking,
  explicit overwrite, source lineage, mirrored state, and final cell data.
