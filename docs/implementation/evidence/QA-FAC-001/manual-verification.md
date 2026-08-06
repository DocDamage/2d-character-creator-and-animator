# Manual Acceptance Scenario

1. Open **Facing Grid Directions** and create 4-way, 8-way, 16-way, and valid
   custom direction sets; confirm one-name custom input is rejected.
2. Select cells to assign/replace/clear asset IDs, batch-place matching
   filenames, swap left/right slots, and mirror into a populated destination
   only after enabling overwrite.
3. Select hard switch, nearest direction, and sprite crossfade; use the
   continuous scrubber at a directional midpoint to confirm the reported
   evaluator outcome.
4. Store compatible mesh states for adjacent cells and confirm midpoint mesh
   interpolation; verify mismatch feedback is recoverable.
5. Use Missing Cell Diagnostics to navigate to and correct an unassigned
   direction.
6. Enable pixel mode while crossfade is selected and confirm hard evaluation.
7. Save/reopen the grid and repeat the midpoint checks to confirm direction,
   mesh, blend, and pixel state are preserved.

Automated coverage recorded in `test-results.txt` executes the same workflow
headlessly; graphical interaction remains suitable for the next human smoke
test when a display environment is available.
