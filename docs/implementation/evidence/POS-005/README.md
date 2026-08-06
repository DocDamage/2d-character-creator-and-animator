# Additive Pose Evidence

## Task ID

`POS-005`

## Status

IMPLEMENTED_UNVERIFIED. Saved additive poses now compose their normalized local
offsets onto a matching rig, and the Saved Poses dock can capture explicitly
as absolute or additive. `QA-POS-001` remains the independent acceptance gate.

## Evidence

- Additive local position and rotation values are added to the rig's current
  values; additive scale is component-wise multiplied.
- Rig identity and missing-bone diagnostics are shared with absolute pose
  application.
- The user-facing capture form now explicitly chooses **Absolute** or
  **Additive offsets**, persisting that choice on the new named pose.
- Integration coverage verifies position, rotation, scale composition and UI
  mode persistence.

## Scope Boundary

Pose thumbnails and sketch-to-pose assistance remain `POS-006` and `POS-007`
scope.
