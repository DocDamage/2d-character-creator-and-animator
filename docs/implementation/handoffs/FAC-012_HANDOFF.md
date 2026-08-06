# FAC-012 Handoff — Implement pixel no-crossfade mode

## Thread Identity

- Task ID: FAC-012
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable persistent pixel-mode authoring switch.
- Explicit hard-direction evaluation override and status feedback when pixel
  mode is active.

### Out of scope

- No further Phase 1 facing authoring controls. The remaining work is
  independent `QA-FAC-001` acceptance.

## Requirements Addressed

- Master plan §12, `FAC-012`.
- `REQ-FAC-012`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_pixel_mode_controls.gd`
- `facing/facing_pixel_mode_controls.tscn`
- `docs/implementation/evidence/FAC-012/`
- `docs/implementation/handoffs/FAC-012_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning, traceability, and reconciliation documentation.

## Work Performed

- Added a pixel-mode toggle to the reachable direction editor.
- Used the existing grid field and evaluator override rather than duplicating
  pixel-mode evaluation logic.
- Covered crossfade-to-pixel hard-switch behavior and serialization in the
  integration test.

## Acceptance Criteria

- PASS: user-reachable pixel mode explicitly suppresses crossfades.
- PASS: the persisted grid evaluates a midpoint as a hard direction while
  pixel mode is active.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.
- `godot --headless --path . --script tools/loc_checker/loc_checker.gd`
- Result: 212 files scanned; none exceed 300 lines.
- `godot --headless --path . --script tools/stub_scanner/stub_scanner.gd`
- Result: 209 files scanned; no stubs or placeholders found.

## Manual Verification

- Scenario: `docs/implementation/evidence/FAC-012/manual-verification.md`.
- Expected: pixel mode suppresses crossfades without altering the selected
  saved blend mode.

## Persistence and Round Trip

- `FacingGridDefinition.pixel_mode` is a standard serialized field; the
  integration test checks it after a grid round trip.

## Negative and Edge Cases

- Pixel mode leaves crossfade configuration intact but deterministically
  overrides its evaluation to hard selection.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scans.

## Known Issues

- None within this task’s scope.

## Remaining Work

- Independent `QA-FAC-001` acceptance across the complete authoring workflow.

## Traceability Updates

- `REQ-FAC-012`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: QA-FAC-001
- Thread type: VERIFICATION
- Reason: independently verify the complete authoring-to-runtime facing-grid
  workflow before treating Phase 1 facing work as accepted.
