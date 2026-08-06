# FAC-009 Handoff — Implement deformable-mesh direction blending

## Thread Identity

- Task ID: FAC-009
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Directional storage of mesh IDs, optional topology IDs, and deformation
  vertex states from the reachable Facing Grid Directions panel.
- Compatibility feedback, per-cell mesh-blend opt-in, and interpolated vertex
  results for compatible directional crossfades.

### Out of scope

- Continuous direction scrub preview (`FAC-010`).
- Missing-cell diagnostics (`FAC-011`) and pixel no-crossfade controls
  (`FAC-012`).

## Requirements Addressed

- Master plan §12, `FAC-009`.
- `REQ-FAC-009`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_mesh_blend_model.gd`
- `facing/facing_mesh_blend_controls.gd`
- `facing/facing_mesh_blend_controls.tscn`
- `docs/implementation/evidence/FAC-009/`
- `docs/implementation/handoffs/FAC-009_HANDOFF.md`

## Files Modified

- `facing/facing_grid_evaluator.gd`
- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning, traceability, and reconciliation documentation.

## Work Performed

- Added panel controls to store a selected cell’s mesh deformation state in
  standard facing-grid data.
- Validated shared mesh IDs, optional topology IDs, vertex counts, vertex
  syntax, and explicit mesh-blend opt-out before interpolation.
- Included compatible interpolated vertices in the runtime evaluator’s
  crossfade response while retaining the safe sprite crossfade when mesh data
  is incompatible.
- Covered valid panel authoring, malformed input, mismatch rejection, status
  feedback, and midpoint interpolation in the direction-editor integration
  test.

## Acceptance Criteria

- PASS: an author can store mesh deformation vertices for neighboring cells.
- PASS: compatible cells return interpolated vertices at a directional
  midpoint.
- PASS: malformed vertex input and incompatible mesh IDs are rejected.
- PASS: the panel displays compatibility feedback for the next direction.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.
- `godot --headless --path . --script tools/loc_checker/loc_checker.gd`
- Result: 208 files scanned; none exceed 300 lines.
- `godot --headless --path . --script tools/stub_scanner/stub_scanner.gd`
- Result: 205 files scanned; no stubs or placeholders found.

## Manual Verification

- Scenario: `docs/implementation/evidence/FAC-009/manual-verification.md`.
- Expected: compatible states report ready and interpolate; invalid states
  explain the block without overwriting saved data.

## Persistence and Round Trip

- Mesh ID and deformation data are normalized into the existing per-cell
  `FacingGridDefinition` serialization dictionary.

## Negative and Edge Cases

- Empty or mismatched mesh IDs, incompatible topology IDs, invalid vertex
  syntax, unequal vertex counts, and a disabled cell do not produce a mesh
  blend.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scans.

## Known Issues

- The panel reports compatibility; it does not render a continuous visual
  scrub preview until `FAC-010`.

## Remaining Work

- `FAC-010` through `FAC-012` and independent `QA-FAC-001` acceptance.

## Traceability Updates

- `REQ-FAC-009`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: FAC-010
- Thread type: IMPLEMENTATION
- Reason: use the now-authorable sprite and mesh blend states in a continuous
  direction-scrub preview.
