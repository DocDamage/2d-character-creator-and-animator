# Manual Verification Scenario

1. Open **Facing Grid Directions** with a partially populated 4- or 8-way
   grid.
2. Confirm **Missing Cell Diagnostics** reports the missing count and lists
   every missing direction by name.
3. Select a list item. Confirm it becomes the active direction in the editor,
   ready for asset or mesh assignment.
4. Assign an asset or store mesh data for that direction. Confirm the list and
   count refresh without reopening the panel.
5. Fill all directions. Confirm the panel reports that all directional cells
   are assigned and the list is empty.
6. Save/reopen the grid and confirm the diagnostic result is regenerated from
   the persisted cell data.

Pixel no-crossfade remains `FAC-012` scope.
