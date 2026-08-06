# POS-005 Handoff — Implement additive poses

## Thread Identity

- Task ID: POS-005
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Compose additive normalized pose deltas onto a matching rig.
- Expose an explicit absolute/additive capture choice.

### Out of scope

- Pose thumbnails and sketch assistance (`POS-006`, `POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-005`.
- `REQ-POS-005`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Modified

- `rigging/poses/pose_applier.gd`
- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `tests/integration/test_pose_authoring.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Defined additive application as position/rotation addition and component-wise
  scale multiplication.
- Reused matching-rig and missing-bone protections from normal application.
- Added explicit capture-mode controls and tested persisted additive mode.

## Real Behavior Demonstrated

The test applies a known delta to a non-zero, non-unit base transform and
confirms exact composed position, rotation, and scale values.

## Acceptance Criteria

- PASS: additive position and rotation compose with base transforms.
- PASS: additive scale multiplies the base scale per component.
- PASS: absolute application still replaces transforms.
- PASS: the capture UI saves selected additive mode.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`.

## Manual Verification

See `docs/implementation/evidence/POS-005/manual-verification.md`.

## Persistence and Round Trip

`PoseDefinition.mode` already round-trips through the pose library; capture
now sets that field through the user-facing control.

## Negative and Edge Cases

- Wrong rig IDs and no matching bones fail without applying data.
- Existing non-additive poses preserve absolute replacement behavior.

## Stub and Reachability Scan

- Commands: stub scanner and pose-authoring integration test.
- Findings: no stubs; user capture mode reaches the shared application path.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- Additive capture records current local transforms as deltas; a rest-relative
  delta authoring editor is a separate higher-level authoring enhancement.

## Remaining Work

- `POS-006`, `POS-007`, `RET-001` through `RET-006`, and `QA-POS-001`.

## Traceability Updates

- `REQ-POS-005`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_applier.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: POS-006
- Thread type: IMPLEMENTATION
- Reason: generate clear saved-pose thumbnails for browsing and selection.

## New Thread Start Prompt

Implement `POS-006` from the master plan: create deterministic pose-thumbnail
data and user-visible thumbnail browsing in Saved Poses, test rendering-state
derivation and selection, document evidence, and preserve the 300-line limit.
