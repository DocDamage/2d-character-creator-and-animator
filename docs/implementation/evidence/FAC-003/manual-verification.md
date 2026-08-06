# Manual Verification Scenario

1. Open the **Facing Grid Directions** panel and select a direction cell.
2. Type an asset ID in **Asset ID** and press **Assign**. Confirm the cell
   becomes Assigned and the summary’s assigned/missing count changes.
3. Replace the ID with another value and press **Assign**. Confirm the selected
   cell shows the replacement without affecting other directional cells.
4. Press **Clear**. Confirm that the cell becomes Unassigned, the clear button
   disables, and the grid reports one missing direction.
5. Press **Assign** with an empty ID or **Clear** on an unassigned cell.
   Confirm a recoverable explanatory message appears.
6. Save/reopen serialized grid data and confirm only assigned directions retain
   their asset IDs.

Asset selection from a browser and automatic batch placement are intentionally
outside this task’s scope.
