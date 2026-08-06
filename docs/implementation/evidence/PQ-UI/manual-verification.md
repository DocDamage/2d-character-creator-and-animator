# Manual Verification — PQ-UI

## Render review

- **Startup at 1440 × 960**: PASS. Header, recent projects, project diorama, quick actions, health state, route guidance, and overview bar fit without overlap.
- **Project workspace at 1440 × 960**: PASS. Six workspace tabs, left/center/right docks, project hub, timeline, and status bar remain legible and contained.
- **Weapon workspace at 1440 × 960**: PASS. Weapon stage, authoring controls, coverage status, saved poses, inspector, and diagnostics retain the existing workflow.
- **Export workspace at 1440 × 960**: PASS. Sprite-sheet preview, variant queue controls, hierarchy, preview panel, timeline, and status bar fit without clipping.
- **Windows release startup at 1440 × 960**: PASS. The shipped EXE reports 5/5 startup checks, shows the bundled `humanoid_modular` sample, and keeps every action and status panel visible.
- **Windows release project transition at 1440 × 960**: PASS. Clicking **Explore starter sample** opens the editor and changes the native window title to `humanoid_modular.chrproj - Paper Quest Character Studio`.
- **Responsive dock regression**: PASS. The Project hub, its status chip, and all dock panels stay inside their regions; tabbed docks keep compact collapse controls without duplicate headings.

## Interaction review

- Native Godot buttons and tabs retain keyboard/controller focus behavior.
- Status colors are paired with visible text and tooltips.
- Craft, Dark Craft, and High Contrast remain settings-backed appearances.
- Reduced-motion, texture visibility, and DPI behavior remain service-controlled.
- The packaged acceptance runner exercises the Open Project dialog, starter-sample route, all six workspace switches, 16 dock panels, command palette, and all three appearance modes.

No known rendering regression was observed in the final source or Windows-package captures. This review is implementation verification, not external user-acceptance testing.
