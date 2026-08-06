# RET-001 Handoff — Define skeleton profiles

## Thread Identity

- Task ID: RET-001
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-06
- Repository, branch, commits: no Git repository detected.

## Scope

### In scope

- Serializable semantic skeleton-profile contract and validation.

### Out of scope

- Mapping, proportion compensation, preview, batch processing, corrections,
  and independent retarget QA (`RET-002` through `RET-006`, `QA-POS-001`).

## Requirements Addressed

- Master plan Milestone 11, `RET-001`.
- `REQ-RET-001`: IMPLEMENTED_UNVERIFIED pending `QA-POS-001`.

## Files Created

- `rigging/retargeting/skeleton_profile.gd`
- `tests/integration/test_retargeting.gd`
- `docs/implementation/evidence/RET-001/`
- `docs/implementation/handoffs/RET-001_HANDOFF.md`

## Files Modified

- `tests/test_runner.gd`
- Completion-plan traceability and ledger records.

## Work Performed

- Defined profile identity, rig ID, unique semantic role/bone mappings, and
  metadata with stable dictionary serialization.
- Added validation of missing root, blank/duplicate assignments, and optional
  bound-rig membership.
- Added a dedicated retargeting integration suite to the runner.

## Real Behavior Demonstrated

The test creates a profile for `hero_rig`, normalizes a role label, round-trips
its data, and rejects duplicate/unknown role assignments.

## Acceptance Criteria

- PASS: profile roles normalize, validate, and serialize deterministically.
- PASS: profile root/identity/mapping errors are recoverable.
- PASS: full suite reports `460 PASS, 0 FAIL`.

## Automated Tests

- `godot --headless --path . --scene tests/test_runner.tscn`
- Result: `460 PASS, 0 FAIL`.

## Manual Verification

See `docs/implementation/evidence/RET-001/manual-verification.md`.

## Persistence and Round Trip

`to_dict()` sorts semantic roles and `from_dict()` restores normalized values.

## Negative and Edge Cases

- Missing root, duplicate bone IDs, blank fields, and unavailable IDs reject.

## Stub and Reachability Scan

- Commands: stub scanner and retargeting integration test.
- Findings: no stubs; profile source is used by the next mapping task.

## LOC Compliance

- Files over 300 lines: none.

## Known Issues

- Profiles are a serializable model; a visual profile/mapping workspace will
  arrive with interactive retarget preview work.

## Remaining Work

- `RET-002` through `RET-006` and `QA-POS-001`.

## Traceability Updates

- `REQ-RET-001`: IMPLEMENTED_UNVERIFIED.

## Git Summary

- Not applicable; this workspace has no Git metadata.

## Required Files for Next Thread

- `rigging/retargeting/skeleton_profile.gd`
- `tests/integration/test_retargeting.gd`

## Next Task Recommendation

- Task ID: RET-002
- Thread type: IMPLEMENTATION
- Reason: validate source/target semantic mappings and missing-role diagnostics.

## New Thread Start Prompt

Implement `RET-002` from the master plan: create validated source-to-target
semantic bone mapping based on skeleton profiles, report missing/ambiguous
roles, test mapping outcomes, document evidence, and preserve the 300-line
limit.
