# FAC-003 Handoff — Implement selected-cell asset assignment

## Thread Identity

- Task ID: FAC-003
- Task title: Implement selected-cell asset assignment
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-05
- Repository: No Git repository detected
- Branch/commits: not applicable

## Scope

### In scope

- Assign, replace, and clear an asset ID in the selected facing-grid cell.
- Visible selection/assignment controls, dirty state, diagnostics, and round trip.

### Out of scope

- Filename and folder batch placement (`FAC-004`), slot swapping, mirroring,
  previews, authoring diagnostics, crossfades, and pixel controls.

## Requirements Addressed

- Master plan §12, `FAC-003`.
- `REQ-FAC-003` is IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `docs/implementation/evidence/FAC-003/`
- `docs/implementation/handoffs/FAC-003_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- `docs/implementation/TASK_LEDGER.md`
- `docs/implementation/REQUIREMENTS_TRACEABILITY.md`
- `docs/implementation/MASTER_PLAN_RECONCILIATION.md`

## Work Performed

- Added an asset-ID input and Assign/Clear controls that follow the selected
  direction in the panel.
- Added public APIs for assignment and clearing, preserving known cell fields
  on replacement and removing a cleared cell so missing-cell state is correct.
- Extended the focused integration test to exercise assign, replace, clear,
  diagnostics, status, and serialization.

## Real Behavior Demonstrated

After selecting a cell, an asset ID is assignable from the panel, replacement
is immediate, clearing makes that direction genuinely missing, and the emitted
grid remains serializable.

## Acceptance Criteria

- PASS: selected cells accept and replace nonempty asset IDs.
- PASS: empty assignment and absent clear operations give recoverable feedback.
- PASS: clearing updates cell/missing status without damaging other directions.
- PASS: the full Godot suite passes.
- Evidence: `docs/implementation/evidence/FAC-003/`.

## Automated Tests

- Command: `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `456 PASS, 0 FAIL`.
- Focused test: `tests/integration/test_facing_direction_editor.gd`.

## Manual Verification

- Steps, expected behavior, and scope limit: `docs/implementation/evidence/FAC-003/manual-verification.md`.

## Persistence and Round Trip

- Save/reopen: focused test persists the grid after a clear operation.
- Export/import and clean consumer: later export/runtime master-plan scope.

## Negative and Edge Cases

- Empty asset ID: rejected with a recovery message.
- Clear without assignment: rejected with a recovery message.
- Replacement: retains the selected cell and replaces only its asset ID.
- Clear: removes the selected cell so missing directions remain accurate.

## Stub and LOC Compliance

- Commands: `docs/implementation/evidence/FAC-003/commands.log`.
- Findings: no stubs and no files over 300 lines after governance scan.

## Known Issues

- Asset ID entry is intentionally a focused assignment surface; asset-browser
  picker and automatic naming/folder placement are later tasks.

## Remaining Work

- `FAC-004` filename-based batch placement.
- `QA-FAC-001` independent full workflow verification.

## Traceability Updates

- `REQ-FAC-003`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- No Git repository is present, so no commit or branch can be reported.

## Required Files for Next Thread

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`

## Next Task Recommendation

- Task ID: FAC-004
- Thread type: IMPLEMENTATION
- Reason: extend the same assignment surface with deterministic filename-based batch placement.

## New Thread Start Prompt

Implement master-plan task `FAC-004` after adding its ledger row. Add a
reachable filename-convention batch placement workflow to the Facing Grid
Directions panel. It must preview planned assignments, reject ambiguous or
unknown names safely, make one deterministic application, cover 4/8/16/custom
sets with focused tests, and record implementation-only evidence pending
`QA-FAC-001`.
