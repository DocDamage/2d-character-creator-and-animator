# FAC-011 Handoff — Implement missing-cell diagnostics

## Thread Identity

- Task ID: FAC-011
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable current-state summary and full list of missing directional
  cells.
- Direct navigation from a diagnostic entry into the existing selected-cell
  correction workflow.

### Out of scope

- Pixel no-crossfade controls (`FAC-012`).

## Requirements Addressed

- Master plan §12, `FAC-011`.
- `REQ-FAC-011`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_missing_cell_diagnostics.gd`
- `facing/facing_missing_cell_diagnostics.tscn`
- `docs/implementation/evidence/FAC-011/`
- `docs/implementation/handoffs/FAC-011_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning, traceability, and reconciliation documentation.

## Work Performed

- Added a diagnostic panel backed by the production missing-direction API.
- Refreshed it through the normal grid-change path and enabled direct selection
  of a missing cell for immediate correction.
- Covered list contents and diagnostic-driven selection in the integration
  test.

## Acceptance Criteria

- PASS: all missing direction IDs are visibly listed.
- PASS: selecting a diagnostic entry activates that direction in the editor.
- PASS: normal grid updates refresh the list.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.
- `godot --headless --path . --script tools/loc_checker/loc_checker.gd`
- Result: 211 files scanned; none exceed 300 lines.
- `godot --headless --path . --script tools/stub_scanner/stub_scanner.gd`
- Result: 208 files scanned; no stubs or placeholders found.

## Manual Verification

- Scenario: `docs/implementation/evidence/FAC-011/manual-verification.md`.
- Expected: current missing IDs are listed and a selection navigates into the
  existing correction controls.

## Persistence and Round Trip

- No separate data is persisted; diagnostics regenerate from serialized cells.

## Negative and Edge Cases

- Empty grids and fully assigned grids show an empty diagnostic list with a
  recoverable summary rather than stale entries.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scans.

## Known Issues

- This panel identifies and navigates missing cells; it intentionally does not
  auto-generate assets for them.

## Remaining Work

- `FAC-012` and independent `QA-FAC-001` acceptance.

## Traceability Updates

- `REQ-FAC-011`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: FAC-012
- Thread type: IMPLEMENTATION
- Reason: add the final per-grid pixel no-crossfade authoring control and then
  run authoritative facing-grid QA.
