# FAC-007 Handoff — Implement hard direction switching controls

## Thread Identity

- Task ID: FAC-007
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable authoring action that configures hard directional switching.
- Normal dirty-state notification and serializable grid change.

### Out of scope

- Crossfade selection (`FAC-008`), mesh blending, preview, diagnostics, and
  pixel controls.

## Requirements Addressed

- Master plan §12, `FAC-007`.
- `REQ-FAC-007`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `docs/implementation/evidence/FAC-007/`
- `docs/implementation/handoffs/FAC-007_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning/traceability/reconciliation documentation.

## Work Performed

- Added an explicit hard-switch control to the direction editor.
- Set the grid’s default blend mode to `HARD_SWITCH` through the user-facing
  action and covered the change from a crossfade setting.

## Acceptance Criteria

- PASS: user-reachable action selects hard switching.
- PASS: setting serializes as the grid default blend mode.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.

## Manual Verification

- `docs/implementation/evidence/FAC-007/manual-verification.md`.

## Persistence and Round Trip

- `default_blend_mode` is a standard `FacingGridDefinition` serialized field.

## Negative and Edge Cases

- The action safely overrides an existing crossfade setting to the deterministic hard mode.

## Stub and LOC Compliance

- Final commands and results are recorded with the evidence bundle.

## Known Issues

- Crossfade can be evaluated but is not author-selectable until `FAC-008`.

## Remaining Work

- `FAC-008` through `FAC-012` and `QA-FAC-001`.

## Traceability Updates

- `REQ-FAC-007`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; no Git metadata exists.

## Next Task Recommendation

- Task ID: FAC-008
- Thread type: IMPLEMENTATION
- Reason: make optional sprite crossfade author-selectable and per-cell controllable.
