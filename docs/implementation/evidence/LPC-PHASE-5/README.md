# LPC Phase 5 Evidence

Phase 5 implements strict, source-bound per-frame LPC deformation with a real
deterministic raster Bake.

- `lpc/deformation/lpc_frame_mesh.gd` provides the versioned v2 frame mesh,
  immutable rest geometry, source/frame/mask binding, topology provenance, and
  migration path.
- `lpc/deformation/lpc_frame_mesh_factory.gd` creates deterministic cropped
  rectangular grids, alpha-cell topology that records disconnected islands and
  transparent holes, and validated manual meshes.
- `lpc/deformation/lpc_frame_mesh_controls.gd` evaluates direct offsets,
  radial pins, true bilinear lattice controls, and soft drags in a documented
  non-destructive order before locked anchors are restored.
- `lpc/deformation/lpc_strict_frame_baker.gd` uses the strict CPU triangle
  rasterizer to write a PNG, deterministic output hash, immutable render
  snapshot, and audit JSON artifact.
- `lpc/deformation/lpc_deformation_diagnostics.gd` checks source binding,
  indices, winding/foldovers, self-overlap, UVs, stretch, bounds, coverage,
  palette, alpha, and shared-edge overlap diagnostics.
- `lpc/deformation/lpc_deformation_workspace_model.gd`,
  `lpc/export/lpc_warp_exporter.gd`, and `lpc/ui/lpc_deform_panel.gd` make the
  workflow reachable, reversible, persistent, autosaved, and exportable.

Verification command:

```powershell
godot --headless --path . --scene tests/lpc_phase5_runner.tscn
```

The synthetic acceptance run creates a frame-bound grid mesh, exercises every
Phase 5 control family, proves source immutability, verifies deterministic PNG
and JSON audit artifacts, checks palette/alpha invariants and crack-free
coverage, rejects changed-source and flipped-triangle inputs, validates
alpha-aware islands/holes and manual topology, saves/reopens/autosaves,
executes a typed mesh-control hybrid track, and proves exported-PNG parity.
