# POS-002 Handoff — Implement save/apply pose

## Thread Identity

- Task ID: POS-002
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Capture a named absolute pose from a rig dictionary.
- Save/retrieve/round-trip named poses and apply them to the same rig.
- User-reachable capture/apply controls and recoverable diagnostics.

### Out of scope

- Mirror pose, weighted blend, additive evaluation, thumbnails, and sketch
  assistance (`POS-003` through `POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-002`.
- `REQ-POS-002`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_applier.gd`
- `rigging/poses/pose_library.gd`
- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `docs/implementation/evidence/POS-002/`
- `docs/implementation/handoffs/POS-002_HANDOFF.md`

## Files Modified

- `app/shared_ui/main_window.gd`
- `tests/integration/test_pose_authoring.gd`
- `tests/unit/test_dock_layout.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Captured `local_position`, `local_rotation`, and `local_scale` into the
  normalized `PoseDefinition` format.
- Added deterministic library serialization with validation on save/reopen.
- Applied absolute poses only when their rig ID matches, reporting absent
  bones and wrong-rig attempts instead of silently changing data.
- Added the **Saved Poses** dock plus `MainWindow.bind_pose_rig` so the app
  host can connect the currently edited rig to the controls.

## Real Behavior Demonstrated

The automated dock test binds a rig through the main-window API, captures
`dock_idle`, changes a bone transform, and applies the saved pose to restore
the original transform. The integration test independently covers library
round-trip and wrong-rig rejection.

## Acceptance Criteria

- PASS: capture records all requested current rig transforms.
- PASS: saved poses reload deterministically and apply their transforms.
- PASS: wrong-rig and no-matching-bone cases return recoverable diagnostics.
- PASS: shell exposes a functional Saved Poses dock.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`; no focused engine, script, or test errors.
- Policy scans: 217 files comply with the 300-line limit; 214 production
  files have no stubs or placeholders.

## Manual Verification

See `docs/implementation/evidence/POS-002/manual-verification.md` for the
capture, mutate, restore, and diagnostic scenario.

## Persistence and Round Trip

- `PoseLibrary.to_dict()` emits saved poses sorted by ID.
- `PoseLibrary.from_dict()` restores validated `PoseDefinition` data.
- Project-document integration and exported runtime pose playback remain
  separate later work.

## Negative and Edge Cases

- Empty/malformed poses fail library validation.
- Empty rigs, unknown selected poses, rig-ID mismatches, and missing pose bones
  return messages and leave unrelated rig data untouched.
- Additive modes are explicitly rejected by this absolute-only apply path.

## Stub and Reachability Scan

- Commands: `tools/stub_scanner/stub_scanner.gd` and dock integration test.
- Findings: no stubs; Saved Poses dock and its host binding route are tested.

## LOC Compliance

- Files over 300 lines: none.
- `app/shared_ui/main_window.gd` remains exactly at the 300-line maximum.

## Known Issues

- Pose-library data is serializable but not yet registered in the project
  document's top-level persistence schema.

## Remaining Work

- `POS-003` through `POS-007`, `RET-001` through `RET-006`, and
  `QA-POS-001`.

## Traceability Updates

- `REQ-POS-002`: IMPLEMENTED_UNVERIFIED.
- Corrected superseded `IMPLEMENTED_UNVERIFIED` wording in verified grid rows.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_library.gd`
- `rigging/poses/pose_applier.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: POS-003
- Thread type: IMPLEMENTATION
- Reason: add explicit bone-pair mirroring to saved named poses.

## New Thread Start Prompt

Implement `POS-003` from the master plan: mirror a named pose across a
validated bone-pair map, expose it in the Saved Poses workflow, test it with
asymmetric local transforms, document evidence, and preserve the 300-line
limit.
