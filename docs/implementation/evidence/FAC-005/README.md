# Left/Right Slot-Swap Evidence

## Task ID

`FAC-005`

## Status

IMPLEMENTED_UNVERIFIED. The reachable direction panel now swaps all `_left`
and `_right` slot mappings in its selected cell while preserving the rest of
that cell’s data. `QA-FAC-001` remains the independent verifier.

## Evidence

- `FacingGridDefinition.swap_cell_slots` is a public, selected-cell-safe API.
- The panel exposes **Swap Left/Right Slots** and emits normal dirty/serialized
  grid change behavior.
- `tests/integration/test_facing_direction_editor.gd` checks weapon/shield
  reversal alongside asset assignment and persistence behavior.

## Scope Boundary

This is an explicit selected-cell swap. Cross-direction mirroring is a separate
`FAC-006` workflow; direction preview, diagnostics, blending, and pixel
controls remain later tasks.
