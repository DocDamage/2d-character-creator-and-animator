# Manual Verification Scenario

1. Open **Facing Grid Directions** with a grid containing adjacent sprite
   cells.
2. In **Direction blend**, select **Sprite crossfade**.
3. Confirm the status text says that crossfade blends adjacent sprite cells and
   the normal unsaved-project indication appears.
4. Save and reopen the grid. Confirm `default_blend_mode` remains
   `CROSSFADE` and the selector still shows **Sprite crossfade**.
5. Evaluate a direction between neighboring populated cells. Confirm runtime
   evaluation returns the adjacent cells and a crossfade result.
6. Choose **Use Hard Direction Switching** and confirm the selector updates to
   **Hard switch**.

Pixel-mode opt-out remains `FAC-012` scope.
