# LPC Phase 2 Evidence

Phase 2 delivers the focused creator and native LPC animation workflow.

- `lpc/creator/lpc_creator_model.gd` persists compatible project-owned layer
  selections and explicit fallback decisions.
- `lpc/animation/lpc_native_compatibility_resolver.gd` calculates native
  animation support as the visible-layer intersection and reports missing art
  rather than removing it silently.
- `lpc/animation/lpc_native_clip_evaluator.gd` resolves exact sheet frame
  references, direct palette maps, z order, credits, and immutable render
  snapshots for the shared preview/export path.
- `lpc/export/lpc_native_exporter.gd` writes actual PNG frames plus an
  `lpc_native_manifest.json` containing source, credit, snapshot, timing, and
  output-hash information.
- `lpc/ui/lpc_creator_panel.gd` is wired into the main window as the reachable
  three-column LPC Creator when a direct-start LPC project opens.

Verification command:

```powershell
godot --headless --path . --scene tests/lpc_phase2_runner.tscn
```

The synthetic test creates a locked catalog, assembles a body, shirt, and
partially-supported cape, asserts an explicit `walk` conflict, resolves it
with `hide_for_clip`, verifies native playback, exports the nine-frame walk
cycle, saves/reopens the project, and proves immutable source hash stability.
