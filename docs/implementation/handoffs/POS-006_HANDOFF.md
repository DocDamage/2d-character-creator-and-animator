# POS-006 Handoff — Implement pose thumbnails

## Thread Identity

- Task ID: POS-006
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Deterministic raster previews for normalized saved poses.
- User-visible selected-pose thumbnail controls.

### Out of scope

- Sketch-to-pose assistance (`POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-006`.
- `REQ-POS-006`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_thumbnail_model.gd`
- `docs/implementation/evidence/POS-006/`
- `docs/implementation/handoffs/POS-006_HANDOFF.md`

## Files Modified

- `rigging/poses/pose_library_panel.gd`
- `rigging/poses/pose_library_panel.tscn`
- `tests/integration/test_pose_authoring.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Rendered an opaque 128×96 thumbnail from serialized local positions.
- Drew an origin marker plus deterministic bone spokes and markers.
- Added selection-driven thumbnail display and a reusable retrieval method.

## Real Behavior Demonstrated

Automated coverage creates a thumbnail for a two-bone pose, confirms image
size/count/texture, and retrieves a rendered thumbnail through the panel.

## Acceptance Criteria

- PASS: saved poses produce deterministic raster thumbnail data.
- PASS: selected panel poses display their generated preview.
- PASS: empty selection clears stale thumbnail texture and gives guidance.
- PASS: full suite reports `459 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `459 PASS, 0 FAIL`.

## Manual Verification

See `docs/implementation/evidence/POS-006/manual-verification.md`.

## Persistence and Round Trip

Thumbnails are deterministic, derived cache data from `PoseDefinition`; no
binary image payload needs persistence or alters pose serialization.

## Negative and Edge Cases

- Empty/missing pose transforms return a clear failed result.
- Degenerate/single-point positions use a nonzero fitting span and render.

## Stub and Reachability Scan

- Commands: stub scanner and pose-authoring integration test.
- Findings: no stubs; displayed image uses the production thumbnail model.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- Thumbnails visualize normalized local positions rather than sprite/mesh
  render output; visual artwork overlays remain broader preview work.

## Remaining Work

- `POS-007`, `RET-001` through `RET-006`, and `QA-POS-001`.

## Traceability Updates

- `REQ-POS-006`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/poses/pose_definition.gd`
- `rigging/poses/pose_thumbnail_model.gd`
- `rigging/poses/pose_library_panel.gd`
- `tests/integration/test_pose_authoring.gd`

## Next Task Recommendation

- Task ID: POS-007
- Thread type: IMPLEMENTATION
- Reason: turn simple gestures into a recoverable named-pose authoring aid.

## New Thread Start Prompt

Implement `POS-007` from the master plan: add deterministic sketch-to-pose
assistance that produces reviewable pose suggestions without overwriting data,
expose it in Saved Poses, test valid and malformed sketches, document
evidence, and preserve the 300-line limit.
