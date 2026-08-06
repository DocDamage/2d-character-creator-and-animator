# POS-001 Handoff — Define pose schema

## Thread Identity

- Task ID: POS-001
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- A serializable named pose schema with normalized per-bone transforms.
- Absolute/additive mode, rig-profile linkage, tags, metadata, and validation.

### Out of scope

- Save/apply, mirroring, blend/additive evaluation, thumbnails, and sketch
  assistance (`POS-002` through `POS-007`).

## Requirements Addressed

- Master plan Milestone 11, `POS-001`.
- `REQ-POS-001`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/poses/pose_definition.gd`
- `tests/integration/test_pose_authoring.gd`
- `docs/implementation/evidence/POS-001/`
- `docs/implementation/handoffs/POS-001_HANDOFF.md`

## Work Performed

- Defined stable fields and validation for named poses.
- Normalized input aliases to position/rotation/scale serialization.
- Added integrated acceptance coverage and registered it with the Godot test
  runner.

## Acceptance Criteria

- PASS: valid pose data normalizes and serializes deterministically.
- PASS: required fields and empty bone IDs are rejected.
- PASS: full suite reports `458 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `458 PASS, 0 FAIL`.
- Policy scans: 214 files within LOC limit; 211 production files contain no
  stubs or placeholders.

## Persistence and Round Trip

- `PoseDefinition.to_dict()`/`from_dict()` round-trip normalized transforms,
  mode, rig-profile ID, tags, and metadata.

## Known Issues

- No authoring panel or pose application behavior is included until `POS-002`.

## Remaining Work

- `POS-002` through `POS-007`, `RET-001` through `RET-006`, and
  `QA-POS-001`.

## Traceability Updates

- `REQ-POS-001`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Next Task Recommendation

- Task ID: POS-002
- Thread type: IMPLEMENTATION
- Reason: use the schema to capture and apply a pose to a rig.
