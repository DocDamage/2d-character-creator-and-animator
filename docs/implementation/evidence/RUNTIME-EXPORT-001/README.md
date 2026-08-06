# Export and Runtime Completion Evidence

## Task IDs

`EXP-009` through `EXP-012` and `GDT-001` through `GDT-014`.

## Status

IMPLEMENTED_UNVERIFIED. `QA-EXP-BATCH-001` and `QA-GDT-001` remain
independent acceptance tasks.

## Evidence

- The Batch Export dock queues character and weapon variants, reports progress,
  cancels at a safe boundary, validates artifacts, and checks that outputs open.
- Native export maps animation/state data, meshes, sprites, markers, collision
  volumes, weapons, appearance data, and baked fallback metadata for the
  self-contained runtime addon.
- The portable player builds AnimationPlayer/AnimationTree and visual nodes,
  samples stepped/linear tracks, supports weighted Polygon2D bones, and exposes
  appearance persistence, grip targets, importer reports, and debug snapshots.
