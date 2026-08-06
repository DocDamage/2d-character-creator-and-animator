# FAC-002 Handoff — Implement the direction-set editor

## Thread Identity

- Task ID: FAC-002
- Task title: Implement the direction-set editor
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-05
- Repository: No Git repository detected
- Branch: Not applicable
- Starting commit: Not applicable
- Ending commit: Not applicable

## Scope

### In scope

- A dock-reachable 4/8/16/custom direction-set editor.
- Custom-name validation, cell pruning, status display, selected-cell state,
  dirty-state integration, and persisted grid data.

### Out of scope

- Asset assignment (`FAC-003`), filename/folder placement (`FAC-004`), slot
  swapping/mirroring (`FAC-005`/`FAC-006`), preview, diagnostics, blending,
  and pixel controls.

## Requirements Addressed

- Master plan §12, `FAC-002`.
- Traceability row `REQ-FAC-002` is IMPLEMENTED_UNVERIFIED pending `QA-FAC-001`.

## Repository Preflight

- Branch verified: no Git repository.
- Working tree verified: no Git repository metadata is present.
- Previous handoff claims checked: legacy `QA-GRID-001` accepts only runtime/data core.
- Conflicts found: none.

## Files Created

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `tests/integration/test_facing_direction_editor.gd`
- `docs/implementation/evidence/FAC-002/`
- `docs/implementation/handoffs/FAC-002_HANDOFF.md`

## Files Modified

- `facing/facing_grid_definition.gd`
- `app/shared_ui/main_window.gd`
- `tests/test_runner.gd`
- `docs/implementation/TASK_LEDGER.md`
- `docs/implementation/REQUIREMENTS_TRACEABILITY.md`
- `docs/implementation/MASTER_PLAN_RECONCILIATION.md`

## Files Deleted

- None.

## Work Performed

- Added a Control scene that switches between standard and custom direction
  sets and displays each current cell’s assignment state.
- Enforced a minimum of two unique custom names and preserved the last valid
  set on invalid input.
- Made every direction-set switch prune incompatible cell keys, including
  standard-to-standard changes.
- Added the editor as a dock panel and focused regression coverage.

## Real Behavior Demonstrated

The editor is reachable from the application shell, writes to a
`FacingGridDefinition`, flags the project as dirty, emits its serialized grid,
and provides a selected direction for `FAC-003` to assign an asset.

## Acceptance Criteria

- PASS: A user can select 4-, 8-, 16-way, and custom directional grids.
- PASS: Invalid custom input reports a recoverable message without data loss.
- PASS: Cells absent from the new set are pruned and status is refreshed.
- PASS: A user can select a current direction from the panel.
- PASS: The changed grid round-trips through `to_dict`/`from_dict`.
- Evidence: `docs/implementation/evidence/FAC-002/`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `456 PASS, 0 FAIL`.
- Focused test: `tests/integration/test_facing_direction_editor.gd`.

## Manual Verification

- Steps and expected/actual behavior: `docs/implementation/evidence/FAC-002/manual-verification.md`.
- Result: automated coverage passes; manual visual walkthrough remains recorded for the independent QA task.

## Persistence and Round Trip

- Save/reopen: grid serialization is asserted by the focused test.
- Export/import: later Phase 1 export/parity acceptance remains outside this task.
- Clean consumer project: not applicable to direction-set UI.
- Evidence: `docs/implementation/evidence/FAC-002/test-results.txt`.

## Negative and Edge Cases

- One custom name is rejected with a recoverable diagnostic.
- Duplicate custom names are de-duplicated.
- Standard-set changes remove cells no longer valid for the grid.
- Unknown selected direction is rejected without changing selection.

## Stub and Reachability Scan

- Commands: recorded in `docs/implementation/evidence/FAC-002/commands.log`.
- Findings: none after governance scan.
- Classification: no stubs or placeholders.

## LOC Compliance

- Files over 300 lines: none after governance scan.
- Exception records: none.
- Split analysis: editor logic is 204 lines and its scene keeps presentation separate.

## Known Issues

- The panel exposes direction selection but deliberately does not assign assets;
  that user action belongs to `FAC-003`.

## Remaining Work

- `FAC-003` must bind selected directions to asset assignment and persistence.
- `QA-FAC-001` must independently verify all master facing-grid workflows.

## Out-of-Scope Findings

- The existing facing-grid data model already supports mirroring and blending;
  its visual authoring controls remain separate tasks.

## Traceability Updates

- `REQ-FAC-002`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Commit: not applicable; no Git repository.
- Push status: not applicable.
- Remote branch: not applicable.
- Uncommitted changes: repository status unavailable because no Git metadata exists.

## Required Files for Next Thread

- `facing/facing_direction_set_editor.gd`
- `facing/facing_direction_set_editor.tscn`
- `facing/facing_grid_definition.gd`
- `tests/integration/test_facing_direction_editor.gd`

## Next Task Recommendation

- Task ID: FAC-003
- Thread type: IMPLEMENTATION
- Reason: It consumes the selected direction and completes the adjacent cell-asset assignment workflow.

## New Thread Start Prompt

Implement master-plan task `FAC-003` in this workspace. Start by adding its
ledger row. Extend the reachable Facing Grid Directions panel so a selected
direction can receive, replace, and clear an asset while preserving a
deterministic `FacingGridDefinition` round trip. Add focused tests and a full
evidence bundle, leave `REQ-FAC-002` IMPLEMENTED_UNVERIFIED, and do not mark
the master-facing workflow verified before `QA-FAC-001`.
