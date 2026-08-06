# Direction-Scrub Preview Evidence

## Task ID

`FAC-010`

## Status

IMPLEMENTED_UNVERIFIED. The reachable **Facing Grid Directions** panel now
provides a continuous angle scrubber and radial indicator that evaluate the
currently bound grid at every angle. Independent end-to-end facing-authoring
acceptance remains `QA-FAC-001`.

## Evidence

- `facing/facing_direction_scrub_preview.tscn` adds a 0–360° continuous
  slider, radial indicator, selection label, and mesh-preview label.
- The preview routes each angle through `FacingGridEvaluator`, so hard,
  sprite-crossfade, and compatible mesh-blend results match runtime behavior.
- The selection label identifies the primary/secondary cells and crossfade
  weight; the mesh label reports interpolation readiness or a recoverable
  reason it is unavailable.
- `tests/integration/test_facing_direction_editor.gd` scrubs to 45° and
  verifies the forward→right 50% crossfade outcome and the displayed feedback.

## Scope Boundary

This task is a live authoring preview. Missing-cell diagnostics is `FAC-011`;
pixel no-crossfade controls are `FAC-012`; independent workflow acceptance is
`QA-FAC-001`.
