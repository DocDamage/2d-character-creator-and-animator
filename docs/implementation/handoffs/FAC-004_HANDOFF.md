# FAC-004 Handoff — Implement filename-based batch placement

## Thread Identity

- Task ID: FAC-004
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-05
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A reachable preview/apply dialog for deterministic `asset_id | filename`
  directional placement.
- Atomic application and safe diagnostics for invalid plans.

### Out of scope

- Folder scanning, asset-browser selection, slot swapping, mirroring, visual
  preview, missing-cell authoring diagnostics, and pixel controls.

## Requirements Addressed

- Master plan §12, `FAC-004`.
- `REQ-FAC-004`: IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Files Created

- `facing/facing_filename_placement_model.gd`
- `facing/facing_filename_placement_dialog.gd`
- `facing/facing_filename_placement_dialog.tscn`
- `tests/integration/test_facing_filename_placement.gd`
- `docs/implementation/evidence/FAC-004/`
- `docs/implementation/handoffs/FAC-004_HANDOFF.md`

## Files Modified

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/test_runner.gd`
- `docs/implementation/TASK_LEDGER.md`
- `docs/implementation/REQUIREMENTS_TRACEABILITY.md`
- `docs/implementation/MASTER_PLAN_RECONCILIATION.md`

## Work Performed

- Implemented deterministic longest-exact-name matching from filenames to the
  directions currently in a grid.
- Added a preview gate that rejects malformed rows, no-match rows, ambiguous
  matches, and duplicate target directions before a grid changes.
- Applied a valid batch atomically and refreshed the parent panel after success.
- Added 4/8/16/custom regression coverage with negative cases.

## Real Behavior Demonstrated

The user opens the modal from the direction panel, previews all intended
assignments, then applies only a clean plan. A bad plan does not partially
modify any grid cell.

## Acceptance Criteria

- PASS: exact longest direction names map deterministically.
- PASS: clean preview applies every assignment in one operation.
- PASS: malformed, unknown, ambiguous, and duplicate targets are blocked.
- PASS: four-, eight-, sixteen-way, and custom sets pass coverage.
- PASS: full suite reports `457 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- `tests/integration/test_facing_filename_placement.gd`
- Result: `457 PASS, 0 FAIL`.

## Manual Verification

- Steps, expected behavior, and scope limits: `docs/implementation/evidence/FAC-004/manual-verification.md`.

## Persistence and Round Trip

- Batch output is standard `FacingGridDefinition` cell data and remains serializable.
- Export/runtime parity is later master-plan work.

## Negative and Edge Cases

- Malformed `asset_id | filename` row: blocked.
- Missing direction token: blocked.
- Equal-length ambiguous names or duplicate targets: blocked.
- Direction-set change after preview: apply rejects the stale plan.

## Stub and LOC Compliance

- Commands: `docs/implementation/evidence/FAC-004/commands.log`.
- No stubs/placeholders; no file exceeds 300 lines after the governance scan.

## Known Issues

- The explicit `asset_id | filename` format is intentional until asset-browser
  and folder-placement workflows are implemented.

## Remaining Work

- `FAC-005` left/right slot swapping.
- `QA-FAC-001` independent facing-grid authoring verification.

## Traceability Updates

- `REQ-FAC-004`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; no Git metadata exists in the workspace.

## Required Files for Next Thread

- `facing/facing_direction_set_editor.gd`
- `facing/facing_filename_placement_model.gd`
- `facing/facing_filename_placement_dialog.gd`
- `tests/integration/test_facing_filename_placement.gd`

## Next Task Recommendation

- Task ID: FAC-005
- Thread type: IMPLEMENTATION
- Reason: add explicit left/right slot swapping to the same selected-cell workflow.

## New Thread Start Prompt

Implement master-plan task `FAC-005` after adding its ledger row. Make
left/right slot exchange a reachable, reversible selected-cell action in the
Facing Grid Directions panel. Preserve all unrelated cell fields, add focused
tests and an implementation evidence bundle, keep the requirement
IMPLEMENTED_UNVERIFIED, and defer verification to `QA-FAC-001`.
