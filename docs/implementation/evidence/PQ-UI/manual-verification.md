# Manual Verification — PQ-UI

## Render review

- **Startup at 1440 × 960**: PASS. Header, recent projects, project diorama, quick actions, health state, route guidance, and overview bar fit without overlap.
- **Project workspace at 1440 × 960**: PASS. Six workspace tabs, left/center/right docks, project hub, timeline, and status bar remain legible and contained.
- **Weapon workspace at 1440 × 960**: PASS. Weapon stage, authoring controls, coverage status, saved poses, inspector, and diagnostics retain the existing workflow.
- **Export workspace at 1440 × 960**: PASS. Sprite-sheet preview, variant queue controls, hierarchy, preview panel, timeline, and status bar fit without clipping.

## Interaction review

- Native Godot buttons and tabs retain keyboard/controller focus behavior.
- Status colors are paired with visible text and tooltips.
- Craft, Dark Craft, and High Contrast remain settings-backed appearances.
- Reduced-motion, texture visibility, and DPI behavior remain service-controlled.

No known rendering regression was observed in the canonical screenshots. This review is implementation verification, not external user-acceptance testing.
