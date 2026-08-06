# Manual Verification Report — APP-005

> **Task ID:** APP-005  
> **Requirement ID:** REQ-APP-005  
> **Date:** 2026-08-05  

## Execution Verification

Headless runtime verification was performed executing `main_window.tscn` and `test_runner.tscn` in Godot 4.7.1.

### Verified Behaviors

1. **Dirty State Flagging & Counters**:
   - Calling `AppState.mark_dirty()` increments `_unsaved_changes` counter and sets `_is_dirty = true`.
   - Calling `AppState.mark_clean()` or `AppState.clear_dirty()` resets `_unsaved_changes = 0` and sets `_is_dirty = false`.

2. **Clean Undo Point Tracking**:
   - `AppState.update_undo_dirty_state(current_undo_index)` compares the current command stack position against the recorded clean undo index.
   - When user undoes all actions back to the clean point, `_is_dirty` automatically evaluates to `false`.

3. **Window Title Dirty Indicator**:
   - `AppState.get_formatted_title()` dynamically appends ` *` to the application window title whenever unsaved changes exist.

4. **Unsaved Changes Dialog Modal (`UnsavedChangesDialog`)**:
   - `UnsavedChangesDialog` scene instantiates cleanly.
   - Calling `prompt()` displays the dark modal backdrop, title, custom message, and three buttons: Save, Don't Save, and Cancel.
   - Selecting a button fires `choice_made` signal and executes the provided callback.

5. **Autosave Timer & Signals**:
   - `AppState` manages a periodic `Timer` node.
   - Emits `autosave_triggered` signal when project is dirty.

6. **Application Shell Close Intercept**:
   - `MainWindow._notification(NOTIFICATION_WM_CLOSE_REQUEST)` intercepts app closing.
   - Prompts user via `UnsavedChangesDialog` if `AppState.is_dirty()` is true.
