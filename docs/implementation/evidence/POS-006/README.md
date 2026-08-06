# Pose Thumbnail Evidence

## Task ID

`POS-006`

## Status

IMPLEMENTED_UNVERIFIED. Every saved pose can now produce a deterministic raster
thumbnail that is displayed in the **Saved Poses** dock when selected.
`QA-POS-001` remains the independent acceptance gate.

## Evidence

- `PoseThumbnailModel` creates a 128×96 raster from normalized local position
  transforms, including origin marker, bone spokes, and transform markers.
- The dock refreshes the thumbnail on selection and reports the rendered
  transform count, while exposing a callable thumbnail retrieval API.
- Tests validate dimensions, bone count, generated texture availability, and
  panel integration.

## Scope Boundary

Sketch-to-pose assistance remains `POS-007` scope.
