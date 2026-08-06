# Manual Verification Scenario

1. Open **Facing Grid Directions** with a configured grid.
2. Choose **Use Hard Direction Switching**.
3. Confirm the panel reports the mode change and normal project dirty state.
4. Save/reopen the facing-grid data and confirm `default_blend_mode` is hard
   switching.
5. At a midpoint between two directions, confirm runtime evaluation chooses one
   nearest cell rather than returning a crossfade result.

Selectable crossfade controls remain `FAC-008` scope.
