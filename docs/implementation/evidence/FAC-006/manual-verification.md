# Manual Verification Scenario

1. In **Facing Grid Directions**, choose **Mirror Direction Cell**.
2. Choose a populated source and a different empty destination, leave slot swap
   enabled, then mirror. Confirm the destination shows mirrored source data.
3. Repeat with a populated destination. Confirm the dialog blocks the operation
   until **Overwrite destination cell** is explicitly enabled.
4. Confirm mirrored cells record the source direction, invert mirror state, and
   exchange left/right slots when enabled.
5. Save/reopen the facing grid to confirm the copied cell persists.
