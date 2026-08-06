# Sprite Crossfade Controls Evidence

## Task ID

`FAC-008`

## Status

IMPLEMENTED_UNVERIFIED. The reachable **Facing Grid Directions** panel now
offers a grid-level blend-mode selector, including optional **Sprite
crossfade**. Independent end-to-end facing-authoring acceptance remains
`QA-FAC-001`.

## Evidence

- `facing/facing_blend_mode_controls.tscn` exposes Hard switch, Nearest
  direction, and Sprite crossfade choices in the direction editor.
- `FacingBlendModeControls` writes the selected value to
  `FacingGridDefinition.default_blend_mode`, emits a normal grid update, and
  therefore uses the existing dirty-state and serialization path.
- The selector stays synchronized when the existing hard-switch action is
  invoked.
- `tests/integration/test_facing_direction_editor.gd` selects Sprite
  crossfade and verifies that runtime evaluation returns a crossfade result.

## Scope Boundary

This task supplies the grid-level authoring control for sprite crossfade.
Mesh interpolation validation and preview are `FAC-009`; continuous direction
scrub preview is `FAC-010`; missing-cell diagnostics are `FAC-011`; and the
pixel no-crossfade control is `FAC-012`.
