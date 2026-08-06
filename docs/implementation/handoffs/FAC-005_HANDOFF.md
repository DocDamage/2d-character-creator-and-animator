# FAC-005 Handoff — Implement left/right slot swapping

## Thread Identity

- Task ID: FAC-005
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-05
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Selected-cell slot-mapping exchange and visible action.
- Preservation of unrelated cell data, diagnostics, dirty state, and serialization.

### Out of scope

- Cross-direction mirroring (`FAC-006`) and the remaining facing authoring controls.

## Requirements Addressed

- Master plan §12, `FAC-005`.
- `REQ-FAC-005`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `docs/implementation/evidence/FAC-005/`
- `docs/implementation/handoffs/FAC-005_HANDOFF.md`

## Files Modified

- `facing/facing_grid_definition.gd`
- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- planning/traceability/reconciliation documentation.

## Work Performed

- Added `swap_cell_slots` to the grid definition.
- Added a selected-cell panel action and recoverable no-mapping feedback.
- Covered both expected swaps and field preservation in the editor acceptance test.

## Acceptance Criteria

- PASS: `_left` and `_right` slot values exchange in the selected cell.
- PASS: asset ID and unrelated data survive the swap.
- PASS: no mapping produces a safe diagnostic.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `457 PASS, 0 FAIL`.

## Manual Verification

- `docs/implementation/evidence/FAC-005/manual-verification.md`.

## Persistence and Round Trip

- Slot-swapped standard cells round-trip through `FacingGridDefinition`.

## Negative and Edge Cases

- Missing cell/no mappings: action returns false with recovery feedback.
- Multiple mapped values: every left/right occurrence is exchanged.

## Stub and LOC Compliance

- No stubs/placeholders and no over-limit files after the recorded scan.

## Known Issues

- Direction mirroring is intentionally deferred to `FAC-006`.

## Remaining Work

- `FAC-006` mirroring and all remaining `FAC-*` controls.
- Independent `QA-FAC-001` acceptance.

## Traceability Updates

- `REQ-FAC-005`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `facing/facing_grid_definition.gd`
- `facing/facing_direction_set_editor.gd`
- `tests/integration/test_facing_direction_editor.gd`

## Next Task Recommendation

- Task ID: FAC-006
- Thread type: IMPLEMENTATION
- Reason: present the existing core mirroring operation as a user-reachable authoring workflow.

## New Thread Start Prompt

Implement master-plan task `FAC-006` after adding its ledger row. Add a
reachable direction-to-direction mirroring workflow that safely chooses source
and destination cells, supports slot exchange, preserves source lineage, and
does not overwrite a destination without explicit confirmation. Add tests and
implementation evidence, retaining independent `QA-FAC-001` verification.
