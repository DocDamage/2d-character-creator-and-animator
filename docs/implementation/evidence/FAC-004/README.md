# Filename-Based Batch Placement Evidence

## Task ID

`FAC-004`

## Status

IMPLEMENTED_UNVERIFIED. The Facing Grid Directions panel now opens a modal
planner that previews and atomically applies asset-ID assignments inferred from
filenames. `QA-FAC-001` remains responsible for independent workflow parity.

## Evidence

- `facing/facing_filename_placement_model.gd` parses `asset_id | filename`
  entries, uses the longest exact current direction name, and rejects malformed,
  unknown, ambiguous, or duplicate mappings before any change is applied.
- `facing/facing_filename_placement_dialog.tscn` exposes the preview/apply
  workflow from the reachable direction editor.
- `tests/integration/test_facing_filename_placement.gd` covers four-, eight-,
  sixteen-way, and custom sets, atomic apply, and negative cases.

## Scope Boundary

This task does not scan directories or choose assets from a browser; it owns
the deterministic filename convention and safe batch application only. Folder
placement, slot exchange, mirroring, visual preview, diagnostics, and pixel
controls remain distinct `FAC-*` work.
