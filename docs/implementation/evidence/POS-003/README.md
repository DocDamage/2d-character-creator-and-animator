# Pose Mirror Evidence

## Task ID

`POS-003`

## Status

IMPLEMENTED_UNVERIFIED. A saved pose can now be copied to a new, named mirror
pose across explicit, bidirectional bone pairs. Independent pose/retarget
acceptance remains `QA-POS-001`.

## Evidence

- `PoseMirrorModel` validates pair completeness and one-to-one mapping before
  mirroring a source pose.
- Mirroring negates the local X position and rotation while moving each paired
  transform to the counterpart bone; unpaired bones remain mirrored in place.
- The **Saved Poses** dock parses readable `left:right; ...` pairs, requires a
  new ID, and preserves the source pose by saving the result separately.
- Integrated acceptance covers asymmetric transform conversion, invalid
  one-way pairs, and user-panel invocation.

## Scope Boundary

Weighted blending, additive evaluation, thumbnails, and sketch-to-pose
assistance remain `POS-004` through `POS-007` scope.
