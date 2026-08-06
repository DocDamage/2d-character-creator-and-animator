# Pose Schema Evidence

## Task ID

`POS-001`

## Status

IMPLEMENTED_UNVERIFIED. `PoseDefinition` now provides a serializable named
pose schema for absolute or additive bone transforms, rig-profile linkage,
tags, and metadata. Independent pose/retarget acceptance remains
`QA-POS-001`.

## Evidence

- `rigging/poses/pose_definition.gd` normalizes position, rotation, and scale
  transforms into stable serializable data.
- The schema rejects empty bone IDs, validates required pose fields, and
  preserves rig profile, tags, and metadata through a round trip.
- `tests/integration/test_pose_authoring.gd` verifies normalization,
  validation, rejection, and round-trip behavior.

## Scope Boundary

Saving/applying poses, mirroring, blending, additive evaluation, thumbnails,
and sketch assistance remain `POS-002` through `POS-007` scope.
