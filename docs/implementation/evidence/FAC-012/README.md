# Pixel No-Crossfade Evidence

## Task ID

`FAC-012`

## Status

IMPLEMENTED_UNVERIFIED. The reachable **Facing Grid Directions** panel now
offers a persistent pixel-mode override that forces hard direction changes,
even when the selected grid blend mode is Sprite crossfade. Independent
end-to-end facing-authoring acceptance remains `QA-FAC-001`.

## Evidence

- `facing/facing_pixel_mode_controls.tscn` exposes **Pixel mode (no
  crossfade)** and explains its current effect.
- The control writes the existing serialized `FacingGridDefinition.pixel_mode`
  field and emits the normal dirty-state-aware grid update.
- `FacingGridEvaluator` already treats pixel mode as an explicit hard-switch
  override; the integration test selects crossfade, enables pixel mode, and
  verifies a hard-switch result and serialization round trip.

## Scope Boundary

This completes the Phase 1 facing-grid authoring controls (`FAC-002` through
`FAC-012`). The remaining independent acceptance is `QA-FAC-001`.
