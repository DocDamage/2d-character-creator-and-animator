# Manual Verification Scenario

1. Assign a cell with slot mappings such as `weapon → hand_left` and
   `shield → hand_right`.
2. Select that direction in **Facing Grid Directions** and press **Swap
   Left/Right Slots**.
3. Confirm the mappings become `weapon → hand_right` and `shield → hand_left`,
   while the cell’s asset ID and other transform data remain unchanged.
4. Select a cell with no slot mappings and invoke the action. Confirm the
   editor reports a recoverable message and does not change the grid.
5. Save/reopen the facing grid to confirm slot mappings persist.
