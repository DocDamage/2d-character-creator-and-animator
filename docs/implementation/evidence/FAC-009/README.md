# Deformable-Mesh Direction Blending Evidence

## Task ID

`FAC-009`

## Status

IMPLEMENTED_UNVERIFIED. The reachable **Facing Grid Directions** panel now
lets an author store directional mesh deformation states, validate them against
the next direction, and opt each populated cell into or out of mesh blending.
Independent end-to-end facing-authoring acceptance remains `QA-FAC-001`.

## Evidence

- `facing/facing_mesh_blend_controls.tscn` provides Mesh ID, Topology ID, and
  semicolon-separated deformation vertex inputs for the selected direction.
- `FacingMeshBlendModel` rejects empty or mismatched mesh IDs, topology IDs,
  vertex counts, invalid vertex data, and per-cell opt-outs.
- `FacingGridEvaluator` preserves the normal sprite crossfade result and adds
  compatible interpolated mesh vertices in its `mesh_blend` result.
- The control explains whether blending with the selected cell’s next
  directional neighbor is ready or why it is unavailable.
- `tests/integration/test_facing_direction_editor.gd` stores two mesh states
  through the panel, rejects malformed/incompatible input, and verifies the
  midpoint vertex interpolation.

## Scope Boundary

This task implements storage, compatibility validation, per-cell opt-in, and
runtime evaluation for deformable-mesh directional blending. Continuous
direction scrub preview is `FAC-010`; missing-cell diagnostics is `FAC-011`;
and pixel no-crossfade controls are `FAC-012`.
