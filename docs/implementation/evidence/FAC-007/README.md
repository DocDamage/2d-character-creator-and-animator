# Hard Direction-Switching Evidence

## Task ID

`FAC-007`

## Status

IMPLEMENTED_UNVERIFIED. The reachable Facing Grid Directions panel now lets an
author explicitly select hard directional switching, forcing runtime selection
to use the nearest single cell rather than blending. Independent verification
of the complete facing workflow remains `QA-FAC-001`.

## Evidence

- `FacingDirectionSetEditor` exposes **Use Hard Direction Switching**.
- The action writes `FacingGridDefinition.default_blend_mode` as
  `HARD_SWITCH`, emits a normal serialized-grid update, and marks the project
  dirty through the existing editor path.
- `tests/integration/test_facing_direction_editor.gd` starts from crossfade,
  invokes the authoring action, and verifies the hard-switch setting.

## Scope Boundary

The selectable crossfade authoring control is `FAC-008`; mesh blending,
continuous scrub preview, diagnostics, and pixel controls remain their own
tasks.
