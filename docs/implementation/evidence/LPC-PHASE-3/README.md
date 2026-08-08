# LPC Phase 3 Evidence

Phase 3 implements project-owned pixel and cel authoring.

- `lpc/pixels/lpc_derivative_store.gd` stores immutable, content-addressed PNG
  derivatives under the project UUID and records source hash, frame reference,
  operation, parent derivative, full ancestry, alpha statistics, and palette
  audit.
- `lpc/pixels/lpc_pixel_canvas_model.gd` implements atomic pencil/eraser,
  fill, contiguous and color selection, copy/paste/move, exact-palette checks,
  undo/redo, lossless PNG import/export, and copy-on-first-edit commits.
- `lpc/cels/lpc_cel_timeline.gd` provides typed, timed layer/whole-character
  cels with reference layers and onion-skin queries, including `gap_patch` and
  `cut_mask` kinds.
- `lpc/ui/lpc_pixel_editor_panel.gd` exposes the project workflow through the
  reachable **Pixel & Cels** main-window dock.
- The LPC profile migration adds durable cel/timeline/pixel-workspace state.

Verification command:

```powershell
godot --headless --path . --scene tests/lpc_phase3_runner.tscn
```

The synthetic acceptance check verifies a two-pixel single-stroke command,
undo/redo, selection and paste, chained derivative ancestry, two timed cels,
onion references, no blob creation during autosave, project save/reopen, and
pixel-identical PNG import/export while the source hash stays unchanged.

## Task ID

`LPC-PHASE-3`

## Status

AUTOMATED_VERIFICATION_COMPLETE; human visual and clean-machine release acceptance remain pending.

## Evidence

The focused acceptance runner and the full 556-assertion regression suite pass under Godot 4.7.1.
