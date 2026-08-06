# FAC-008 Handoff — Implement optional sprite crossfade controls

## Thread Identity

- Task ID: FAC-008
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable grid-level selector for hard, nearest, and optional sprite
  crossfade directional blending.
- Persistent, dirty-state-aware grid updates and a synchronized hard-switch
  action.

### Out of scope

- Mesh interpolation validation or preview (`FAC-009`).
- Continuous direction scrub preview (`FAC-010`), diagnostics (`FAC-011`),
  and pixel no-crossfade controls (`FAC-012`).

## Requirements Addressed

- Master plan §12, `FAC-008`.
- `REQ-FAC-008`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_blend_mode_controls.gd`
- `facing/facing_blend_mode_controls.tscn`
- `docs/implementation/evidence/FAC-008/`
- `docs/implementation/handoffs/FAC-008_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning, traceability, and reconciliation documentation.

## Work Performed

- Added a reusable direction-blend selector to the reachable Facing Grid
  Directions panel.
- Bound the selected grid to the control, updated its serialized default blend
  mode, and emitted the normal dirty-state-aware grid change.
- Kept the selector synchronized when the existing hard-switch button is used.
- Added integration coverage that selects crossfade and verifies the runtime
  evaluator returns a crossfade result.

## Acceptance Criteria

- PASS: Sprite crossfade is selectable in the user-reachable direction panel.
- PASS: the selection persists through `FacingGridDefinition` serialization.
- PASS: crossfade evaluation is exercised by the direction-editor integration
  test.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.
- `godot --headless --path . --script tools/loc_checker/loc_checker.gd`
- Result: 206 files scanned; none exceed 300 lines.
- `godot --headless --path . --script tools/stub_scanner/stub_scanner.gd`
- Result: 203 files scanned; no stubs or placeholders found.

## Manual Verification

- Scenario: `docs/implementation/evidence/FAC-008/manual-verification.md`.
- Expected: the selector, status, persistence, midpoint crossfade, and
  hard-switch synchronization behave as described.

## Persistence and Round Trip

- `FacingGridDefinition.default_blend_mode` is an existing serialized grid
  field; this UI writes that field through the normal editor update path.

## Negative and Edge Cases

- The control rejects unsupported blend-mode values.
- The hard-switch action refreshes the selector, avoiding a stale UI value.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scans.

## Known Issues

- Per-cell pixel no-crossfade authoring remains `FAC-012` work.

## Remaining Work

- `FAC-009` through `FAC-012` and independent `QA-FAC-001` acceptance.

## Traceability Updates

- `REQ-FAC-008`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: FAC-009
- Thread type: IMPLEMENTATION
- Reason: expose mesh interpolation validation and author feedback that build
  on the newly selectable direction blend mode.
