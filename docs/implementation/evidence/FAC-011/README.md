# Missing-Cell Diagnostics Evidence

## Task ID

`FAC-011`

## Status

IMPLEMENTED_UNVERIFIED. The reachable **Facing Grid Directions** panel now
exposes all missing directional cells as a diagnostic list and lets an author
select one directly for correction. Independent end-to-end facing-authoring
acceptance remains `QA-FAC-001`.

## Evidence

- `facing/facing_missing_cell_diagnostics.tscn` shows a complete/missing
  summary and an interactive missing-direction list.
- The panel derives diagnostics from the production
  `FacingGridDefinition.missing_directions()` method, refreshes after every
  grid change, and has no independent diagnostic state to drift from saved
  data.
- Selecting a listed entry delegates to the direction editor’s normal
  selection workflow, making it immediately available for asset or mesh
  assignment.
- `tests/integration/test_facing_direction_editor.gd` verifies the exact
  missing IDs and direct selection of the first missing direction.

## Scope Boundary

This task exposes and navigates existing missing-cell data diagnostics. Pixel
no-crossfade controls are `FAC-012`; independent workflow acceptance is
`QA-FAC-001`.
