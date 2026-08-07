# Direct-Start LPC Creator with Animation, Pixel Editing, and Deformation

## Summary

- On launch, resume the last editable LPC project directly in the focused creator. First launch and every New Project show a short chooser for installed pack and a compatible starting body, then create `My Character`, `My Character 2`, etc.
- Keep the startup screen simple; open a dedicated **Animate & Deform** workspace for frame editing, rigging, mesh work, and advanced animation.
- Use the supplied local LPC repository as the source of assets and metadata, but copy the usable library into this workspace first.

## Library and Project Data

- Copy only the LPC distributable library into `third_party/lpc/`: `dist/spritesheets`, generated catalog metadata, sheet/palette definitions, and `CREDITS.csv`; exclude the old app's code, caches, and `node_modules`.
- Keep this local-only and ignored by Git; add a tracked manifest/checksum file so release builds fail clearly when the library is missing or mismatched.
- Build Personal Full and Commercial-safe runtime content packs from that local library:
  - Personal exposes the complete catalog with per-asset license acceptance.
  - Commercial exposes only assets used under CC0, CC-BY, or OGA-BY terms; it never packages GPL or CC-BY-SA-only assets.
- Add `LpcAssetCatalog`, `LpcProjectProfile`, and `LpcCompositeRenderer` interfaces. A project profile stores its locked pack, compatible base family, selections, palettes, credits, license acceptances, full-sheet sources, and project-owned overrides.

## Creator and Advanced Authoring

- Replace the dashboard-first flow with the Paper Quest-styled, 1280x720 three-column creator:
  - Base/features controls left, live front-facing preview center, clothing/equipment controls right.
  - Searchable thumbnail pickers show only compatible assets.
  - Native LPC palette controls preserve pixel-art colors.
  - Footer contains Undo, Reset Body, Export, Credits, and automatic Saved/Saving status.
- Preserve full LPC animation sheets behind the front-facing preview. Add an **Animate & Deform** route into Advanced Studio, where users can create clips, keyframes, rig transforms, and timing.
- Add a production pixel-art editor with layers, cels, pencil, eraser, fill, selection, move, palette tools, onion skin, frame timeline, Undo, PNG import/export, and two animation modes:
  - Whole-character cels: render the assembled character into editable project-owned frames.
  - Per-layer cels: animate body, hair, clothing, and equipment independently.
- Use copy-on-first-edit: bundled LPC art remains untouched; editing clones only the needed layer/sheet into project-owned assets.
- Add a full deformation workspace:
  - Per-layer mesh editing plus optional whole-character composite meshes.
  - Auto/manual mesh topology, UVs, vertex dragging, cage controls, soft drag, bone binding, and weight painting.
  - Mesh/cage and vertex-offset keyframes integrate with animation clips.
  - Changes remain non-destructive by default; Bake produces a project-owned raster asset while retaining editable mesh history.

## Export, Compatibility, and Tests

- Extend rendering/export to composite LPC layers, copied pixel edits, custom cels, and live or baked deformation into PNG sequences, sprite sheets, GIFs, and existing runtime exports; include exact project credits and license records.
- Keep legacy non-LPC projects unchanged and available through Open Project / Advanced Studio; do not auto-convert them.
- Test library intake, pack filtering, missing-library diagnostics, catalog compatibility, first-launch/resume behavior, automatic naming, licensing, autosave, reset, and undo.
- Add visual and rendering tests for layered LPC composition, palette changes, custom cels, per-layer and composite deformation, mesh baking, animation playback, export correctness, and 1280x720 Paper Quest layout.

## Assumptions

- “Deform as I see fit” means both modular per-layer deformation and optional whole-character composite warping.
- The local LPC directory is required for development and release builds but will not be committed to this repository.
- Public releases still require review of the final selected-asset licenses and credits; the app will surface the required records. [LPC licensing and credit guidance](https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator)
