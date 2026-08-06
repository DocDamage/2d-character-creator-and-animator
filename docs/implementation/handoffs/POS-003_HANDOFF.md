# POS-003 Handoff — Implement mirror pose

## Thread Identity

- Task ID: POS-003
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Create a new mirrored pose from a saved source pose.
- Validate explicit bidirectional bone pairs before transformation.
- Expose named mirroring through the reachable Saved Poses dock.

### Out of scope

- Weighted blending, additive evaluation, thumbnails, and sketch assistance
  (`POS-004` through `POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-003`.
- `REQ-POS-003`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_mirror_model.gd`
- `docs/implementation/evidence/POS-003/`
- `docs/implementation/handoffs/POS-003_HANDOFF.md`

## Files Modified

- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `tests/integration/test_pose_authoring.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Added model-level pair validation: non-empty, no self pairing, one-to-one,
  and bidirectional source/target mapping.
- Mirrored normalized local X position and rotation and retained Y/scale.
- Copied source metadata/tags to a new pose with source and axis provenance.
- Added parseable mirror-pair controls that create, save, and select a new pose
  rather than destructively overwriting its source.

## Real Behavior Demonstrated

The integrated test mirrors `hand_left` at `[5, 3]`, `0.4` radians into
`hand_right` at `[-5, 3]`, `-0.4` radians; it rejects a one-way mapping and
creates a named mirror through the UI panel.

## Acceptance Criteria

- PASS: explicit paired transforms move to counterpart bones.
- PASS: X and rotation are negated; Y and scale are retained.
- PASS: invalid, ambiguous, one-way, self, and source-ID-reuse inputs fail.
- PASS: source pose remains separate from its named mirror.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`; no focused engine, script, or test errors.

## Manual Verification

See `docs/implementation/evidence/POS-003/manual-verification.md`.

## Persistence and Round Trip

Mirrored poses use the existing validated `PoseLibrary` serialization path and
record their source pose ID and mirror axis in metadata.

## Negative and Edge Cases

- Empty/invalid pair strings and missing source poses do not mutate the library.
- A mirrored pose cannot reuse its source ID.
- Unpaired bones remain mirrored on the same bone ID, retaining complete poses.

## Stub and Reachability Scan

- Commands: stub scanner and pose-authoring integration test.
- Findings: no stubs; UI mirroring calls the same validated model as the API.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- Mirroring assumes a vertical symmetry axis and supplied counterpart IDs;
  automatic skeleton-pair discovery is retargeting work.

## Remaining Work

- `POS-004` through `POS-007`, `RET-001` through `RET-006`, and
  `QA-POS-001`.

## Traceability Updates

- `REQ-POS-003`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_library.gd`
- `rigging/poses/pose_applier.gd`
- `rigging/poses/pose_mirror_model.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: POS-004
- Thread type: IMPLEMENTATION
- Reason: interpolate compatible absolute poses and expose weighted preview/application.

## New Thread Start Prompt

Implement `POS-004` from the master plan: interpolate compatible named
absolute poses with a deterministic weight, preview/apply the result through
Saved Poses, cover rotation and scale interpolation plus validation, document
evidence, and preserve the 300-line limit.
