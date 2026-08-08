# LPC Phase 4 Evidence

Phase 4 implements typed clips and deterministic hybrid animation.

- `lpc/animation/lpc_typed_track_schema.gd` validates known executable track
  types and key timing; unsupported behavior is never evaluated.
- `lpc/animation/lpc_typed_clip_schema.gd` serializes clip identity, timing,
  direction, loop state, and typed tracks deterministically.
- `lpc/animation/lpc_hybrid_clip_evaluator.gd` is the shared path for native
  source frames, project-owned cels, nearest rigid transforms, visibility,
  z-order, palette maps, direction, event state, and explicit missing
  rig/mesh diagnostics.
- `lpc/export/lpc_hybrid_exporter.gd` produces actual PNG frames and a
  replayable hybrid manifest carrying typed clips, source lock, credits,
  render snapshots, output hashes, and warnings.
- `lpc/ui/lpc_animation_panel.gd` exposes the reachable **Animate · Hybrid
  Clips** dock, synchronized with the creator and pixel-workspace contexts.

Verification command:

```powershell
godot --headless --path . --scene tests/lpc_phase4_runner.tscn
```

The synthetic test authors all phase-4 track categories, runs native body +
custom cel + transformed clothing playback, verifies visibility/event timing,
requires warnings for missing rig/mesh targets, exports three PNG frames,
saves/reopens, and proves the replay hash is stable.

## Task ID

`LPC-PHASE-4`

## Status

AUTOMATED_VERIFICATION_COMPLETE; human visual and clean-machine release acceptance remain pending.

## Evidence

The focused acceptance runner and the full 556-assertion regression suite pass under Godot 4.7.1.
