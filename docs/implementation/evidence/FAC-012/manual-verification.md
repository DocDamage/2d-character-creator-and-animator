# Manual Verification Scenario

1. Open **Facing Grid Directions**, choose **Sprite crossfade** in
   **Direction blend**, and verify the continuous preview shows a crossfade at
   an in-between angle.
2. Enable **Pixel mode (no crossfade)**.
3. Confirm the status says pixel mode forces hard direction changes and the
   preview changes to a hard-selection result.
4. Save/reopen the grid. Confirm pixel mode remains enabled and crossfade is
   still suppressed at a directional midpoint.
5. Disable pixel mode. Confirm the selected direction blend mode controls the
   next evaluation again.

Independent end-to-end facing-grid QA remains `QA-FAC-001`.
