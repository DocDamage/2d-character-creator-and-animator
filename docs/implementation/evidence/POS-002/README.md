# Pose Save and Apply Evidence

## Task ID

`POS-002`

## Status

IMPLEMENTED_UNVERIFIED. Named absolute poses can now capture the active rig,
remain in a serializable pose library, and restore their saved transforms.
`QA-POS-001` remains the independent pose/retarget acceptance gate.

## Evidence

- `PoseApplier` captures canonical local transforms and restores them only to a
  rig matching the pose's saved rig ID.
- `PoseLibrary` validates, saves, retrieves, removes, and deterministically
  serializes named poses.
- The **Saved Poses** dock is reachable through `MainWindow`; its host API
  binds the active rig and its controls capture and apply named poses.
- Integration and dock-layout tests cover transform restoration, library
  round-trip, missing/wrong-rig diagnostics, and application-shell reachability.

## Scope Boundary

Mirroring, weighted blending, additive application, thumbnails, and
sketch-to-pose assistance remain `POS-003` through `POS-007` scope.
