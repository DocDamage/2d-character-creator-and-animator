# DOC-004 Manual Verification Report — Transactional Save (REQ-DOC-004)

## Scenario 1: Successful Transactional Save
- **Given**: Active project data with modified fields and active dirty state (`AppState.is_dirty() == true`).
- **When**: `SerializationService.save_project(data, path)` is executed.
- **Then**:
  1. Serialized project data is written to `path + ".tmp"`.
  2. Complete `ProjectSchema.validate_manifest()` validation passes.
  3. File buffer is flushed and closed.
  4. Rolling backups `.bak` are rotated.
  5. Prior file (if any) is backed up and `.tmp` is atomically renamed to `path`.
  6. Diagnostic journal entry `AppState.post_diagnostic("info", "Transactional save completed...", "SerializationService")` is logged.
  7. `save_completed` signal is emitted.
  8. `AppState.clear_dirty()` is called, clearing dirty state.
- **Result**: PASS

## Scenario 2: Validation Failure Rollback
- **Given**: Project data with missing required fields (e.g. `project_id` missing).
- **When**: `SerializationService.save_project(invalid_data, path)` is executed.
- **Then**:
  1. `.tmp` file is written and flushed.
  2. Manifest schema validation fails.
  3. `.tmp` file is removed immediately (`DirAccess.remove_absolute`).
  4. `save_failed` signal is emitted with diagnostic description.
  5. Diagnostic error entry is logged.
  6. Original target file `path` remains untouched.
  7. `AppState.is_dirty()` remains `true`.
- **Result**: PASS

## Scenario 3: Autosave Isolation
- **Given**: Unsaved manual changes present (`AppState.is_dirty() == true`).
- **When**: `SerializationService.autosave(snapshot_data, autosave_path)` is executed.
- **Then**:
  1. Data is written directly to `autosave_path`.
  2. `AppState.is_dirty()` remains `true` (manual save state not cleared).
  3. Manual save file is not overwritten.
- **Result**: PASS
