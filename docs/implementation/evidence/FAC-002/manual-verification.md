# Manual Verification Scenario

1. Launch the studio and open the **Facing Grid Directions** panel in the
   Animation Studio workspace.
2. Choose **4-way**, **8-way**, and **16-way** in turn. Confirm that the
   direction-cell list updates immediately and its summary states the number
   of directions, assigned cells, and missing cells.
3. Choose **Custom**, enter `forward, right, back, left`, and press **Apply
   Custom Directions**. Confirm that four cells appear and duplicate/blank
   names are not retained.
4. Enter only one custom name and press **Apply Custom Directions**. Confirm
   that an actionable validation message appears and the previous custom set
   remains intact.
5. Select a listed cell. Confirm its selected state is visible; this selection
   is the handoff point for `FAC-003` asset assignment.
6. Save the project through the normal project workflow, reopen its serialized
   facing-grid data, and confirm the selected direction set and cells match.

The automated test performs the data change, pruning, validation, selection,
and serialization portions of this scenario. Visual asset assignment and
preview are intentionally out of scope for `FAC-002`.
