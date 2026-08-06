# POS-007 Handoff — Implement sketch-to-pose assistance

## Thread Identity

- Task ID: POS-007
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Capture a freehand sketch gesture and derive a named pose suggestion.
- Keep suggestions reviewable and non-destructive until explicitly applied.

### Out of scope

- Skeleton profiling, retargeting, and final pose/retarget QA.

## Requirements Addressed

- Master plan Milestone 11, `POS-007`.
- `REQ-POS-007`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_sketch_assist_model.gd`
- `rigging/poses/pose_sketch_canvas.gd`
- `docs/implementation/evidence/POS-007/`
- `docs/implementation/handoffs/POS-007_HANDOFF.md`

## Files Modified

- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `tests/integration/test_pose_authoring.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Added a bounded pointer-stroke canvas with clear interaction.
- Added deterministic gesture-to-bone mapping that fits progress through the
  sketch to current rig position extents and retains local rotation/scale.
- Saved only an explicit named absolute suggestion with `sketch-suggestion`
  metadata; no automatic rig application occurs.

## Real Behavior Demonstrated

The integration test builds a three-point gesture for a two-bone rig, creates
a suggestion, rejects an empty sketch, and saves the panel-generated pose.

## Acceptance Criteria

- PASS: a valid gesture creates a named reviewable pose suggestion.
- PASS: suggestion preserves current rig rotation/scale and adds provenance.
- PASS: empty/malformed sketches fail without saving or applying data.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`.

## Manual Verification

See `docs/implementation/evidence/POS-007/manual-verification.md`.

## Persistence and Round Trip

Suggestions are ordinary validated `PoseDefinition` values stored through
`PoseLibrary`; gesture strokes remain transient UI data.

## Negative and Edge Cases

- Missing ID, empty rig, fewer than two points, and non-Vector2 points reject.
- A suggestion does not alter the rig until the user independently applies it.

## Stub and Reachability Scan

- Commands: stub scanner and pose-authoring integration test.
- Findings: no stubs; the canvas drives the production suggestion model.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- The assist maps gesture progression to sorted bone IDs; semantic
  joint-labelling and AI pose estimation are intentionally outside this scope.

## Remaining Work

- `RET-001` through `RET-006` and `QA-POS-001`.

## Traceability Updates

- `REQ-POS-007`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_sketch_assist_model.gd`
- `rigging/poses/pose_library_panel.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: RET-001
- Thread type: IMPLEMENTATION
- Reason: define reusable skeleton profiles for pose retargeting.

## New Thread Start Prompt

Implement `RET-001` from the master plan: define a serializable skeleton
profile with semantic bone slots and validation, wire it for later retargeting,
test round-trip and malformed data, document evidence, and preserve the
300-line limit.
