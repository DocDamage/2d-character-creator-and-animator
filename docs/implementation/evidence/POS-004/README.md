# Pose Blend Evidence

## Task ID

`POS-004`

## Status

IMPLEMENTED_UNVERIFIED. Compatible absolute named poses can now be blended at a
deterministic 0–100% weight, saved as a new pose, or previewed directly on the
bound rig. `QA-POS-001` remains the independent acceptance gate.

## Evidence

- `PoseBlendModel` requires absolute modes, matching rig IDs, matching bone
  sets, a finite 0–1 weight, and a new result ID.
- It linearly interpolates local position/scale and uses shortest-path angle
  interpolation for rotation.
- The Saved Poses dock selects source and target poses, displays the blend
  weight, saves named blend results, and previews the same result on the rig.
- Tests exercise numerical 25% interpolation, incompatible-pose rejection,
  panel result persistence, and 50% application to the bound rig.

## Scope Boundary

Additive application, thumbnails, and sketch-to-pose assistance remain
`POS-005` through `POS-007` scope.
