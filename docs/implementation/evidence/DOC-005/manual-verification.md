# Manual Verification Report — DOC-005

## Task Overview
- Task ID: DOC-005
- Requirement ID: REQ-DOC-005
- Title: Project load and diagnostics
- Date: 2026-08-05

## Scenarios Verified

### 1. Valid Project Loading
- Action: Call `SerializationService.load_project(valid_path)`.
- Outcome: Valid JSON manifest loaded into Dictionary, `load_completed` signal emitted, info diagnostic posted to `AppState`.

### 2. Missing File Handling
- Action: Call `SerializationService.load_project("non_existent_file.chrproj")`.
- Outcome: Returns empty dictionary `{}` safely without process crash, emits `load_failed`, posts error diagnostic message to `AppState`.

### 3. Corrupt JSON Syntax Handling
- Action: Call `SerializationService.load_project(corrupt_file)`.
- Outcome: Returns empty dictionary `{}` safely, emits `load_failed`, posts JSON parse error diagnostic message to `AppState`.

### 4. Schema Validation Error Reporting
- Action: Attempt to load manifest missing required `project_id` root field.
- Outcome: `SerializationService.load_project` returns empty dictionary, `load_project_with_diagnostics` reports `success=false` and returns schema validation error array, error diagnostics logged to `AppState`.

### 5. Unknown Field Preservation & Detection
- Action: Load manifest containing extra root field (`custom_plugin_data`) and extra object category (`unknown_category`).
- Outcome:
  - `load_project` returns Dictionary containing `custom_plugin_data` and `unknown_category` intact (no data loss).
  - `load_project_with_diagnostics` lists `custom_plugin_data` and `unknown_category` in `unknown_fields` and warning messages in `warnings`.
  - Warning diagnostics posted to `AppState`.

### 6. Diagnostics API Query
- Action: Call `SerializationService.get_last_load_diagnostics()`.
- Outcome: Returns snapshot dictionary of the most recent load operation result (`success`, `data`, `errors`, `warnings`, `unknown_fields`, `schema_version`).
