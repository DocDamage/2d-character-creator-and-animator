# FAC-010 Handoff — Implement direction-scrub preview

## Thread Identity

- Task ID: FAC-010
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable continuous 0–360° directional scrubber and radial indicator.
- Runtime-equivalent selected-cell, crossfade-weight, and compatible mesh
  feedback while an author scrubs the facing angle.

### Out of scope

- Missing-cell diagnostics (`FAC-011`) and pixel no-crossfade controls
  (`FAC-012`).

## Requirements Addressed

- Master plan §12, `FAC-010`.
- `REQ-FAC-010`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_direction_preview_canvas.gd`
- `facing/facing_direction_scrub_preview.gd`
- `facing/facing_direction_scrub_preview.tscn`
- `docs/implementation/evidence/FAC-010/`
- `docs/implementation/handoffs/FAC-010_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning, traceability, and reconciliation documentation.

## Work Performed

- Added a continuous degree slider and custom radial direction indicator to
  the editor.
- Evaluated the active grid through the production evaluator at each scrubbed
  angle, showing hard/crossfade selection and mesh results.
- Connected preview refreshes to normal editor grid changes and covered a 45°
  crossfade preview through the integration test.

## Acceptance Criteria

- PASS: user-reachable slider continuously evaluates 0–360° directions.
- PASS: preview displays selected cells and crossfade weights.
- PASS: compatible mesh interpolation state is reported in the preview.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.
- `godot --headless --path . --script tools/loc_checker/loc_checker.gd`
- Result: 210 files scanned; none exceed 300 lines.
- `godot --headless --path . --script tools/stub_scanner/stub_scanner.gd`
- Result: 207 files scanned; no stubs or placeholders found.

## Manual Verification

- Scenario: `docs/implementation/evidence/FAC-010/manual-verification.md`.
- Expected: the radial indicator and text update continuously and agree with
  runtime direction evaluation.

## Persistence and Round Trip

- The preview has no independent persisted state; it evaluates the existing
  serialized facing-grid state on demand.

## Negative and Edge Cases

- Empty grids show recoverable unavailable feedback.
- Hard and incompatible mesh cases produce their normal safe evaluator
  results rather than a misleading crossfade preview.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scans.

## Known Issues

- The canvas communicates direction and evaluation state; it is not a
  full-texture or mesh renderer.

## Remaining Work

- `FAC-011`, `FAC-012`, and independent `QA-FAC-001` acceptance.

## Traceability Updates

- `REQ-FAC-010`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: FAC-011
- Thread type: IMPLEMENTATION
- Reason: expose the existing missing-cell data diagnostics in the same
  facing-grid authoring workflow.
