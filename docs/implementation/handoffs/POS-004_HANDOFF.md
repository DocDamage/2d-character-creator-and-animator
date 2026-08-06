# POS-004 Handoff — Implement pose blending

## Thread Identity

- Task ID: POS-004
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Deterministically blend compatible absolute poses.
- Save a named result or preview/application on a bound matching rig.

### Out of scope

- Additive evaluation, thumbnails, and sketch assistance (`POS-005`–`POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-004`.
- `REQ-POS-004`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_blend_model.gd`
- `docs/implementation/evidence/POS-004/`
- `docs/implementation/handoffs/POS-004_HANDOFF.md`

## Files Modified

- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `tests/integration/test_pose_authoring.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Added validated absolute-pose blending across identical bone sets.
- Used linear vectors and shortest-path rotation interpolation.
- Added Saved Poses controls for blend target, 1% weight increments, save, and
  bound-rig preview.

## Real Behavior Demonstrated

The integrated test verifies a 25% numerical blend and a 50% UI preview that
applies the expected root position to the active matching rig.

## Acceptance Criteria

- PASS: compatible absolute transforms blend deterministically.
- PASS: position, scale, and shortest-path rotation use the selected weight.
- PASS: incompatible rig/bone/mode/weight inputs are rejected.
- PASS: result is either saved separately or previewed through the same model.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`.

## Manual Verification

See `docs/implementation/evidence/POS-004/manual-verification.md`.

## Persistence and Round Trip

Saved blend results use `PoseLibrary` and include source pose IDs plus blend
weight in their metadata. Direct preview intentionally leaves no library entry.

## Negative and Edge Cases

- Different rig IDs, bone sets, modes, NaN, and out-of-range weights fail.
- Preview requires a matching bound rig and never creates an accidental pose.

## Stub and Reachability Scan

- Commands: stub scanner and pose-authoring integration test.
- Findings: no stubs; model, save, and preview controls use one path.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- The direct preview mutates the bound rig like applying any pose; history-level
  undo integration remains wider authoring work.

## Remaining Work

- `POS-005` through `POS-007`, `RET-001` through `RET-006`, and
  `QA-POS-001`.

## Traceability Updates

- `REQ-POS-004`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_blend_model.gd`
- `rigging/poses/pose_applier.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: POS-005
- Thread type: IMPLEMENTATION
- Reason: apply additive pose deltas on a selected base pose or active rig.

## New Thread Start Prompt

Implement `POS-005` from the master plan: create and apply additive pose
deltas on matching rigs, expose a user-reachable mode and preview in Saved
Poses, test position/rotation/scale composition and validation, document
evidence, and preserve the 300-line limit.
