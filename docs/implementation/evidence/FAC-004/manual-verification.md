# Manual Verification Scenario

1. Open **Facing Grid Directions** and select **Batch Place from Filenames**.
2. Paste one `asset_id | filename` entry per line, such as
   `ast_north | hero_north.png` and `ast_northeast | hero_north_east.png`.
3. Press **Preview**. Confirm each assignment is shown and **Apply Preview**
   becomes available only if every row is valid.
4. Press **Apply Preview**. Confirm the directional list updates in one action.
5. Try a malformed row, an unknown direction name, and two entries mapping to
   the same direction. Confirm preview remains blocked and the grid is unchanged.
6. Repeat with four-way, sixteen-way (`direction_07`), and custom direction
   names, then save/reopen the grid data.

Directory scanning and asset-browser selection are deliberately outside this
filename-convention task.
