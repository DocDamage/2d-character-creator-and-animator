# Manual Verification Report — APP-006: Diagnostics Drawer

## System Under Test
- **Task ID**: APP-006
- **Feature**: Diagnostics Drawer
- **Environment**: Godot 4.7.1 Headless / Application Shell

## Test Scenarios & Results

### Scenario 1: Diagnostics Drawer UI Rendering
- **Step**: Instantiate `DiagnosticsDrawer` in application shell (`panel_diagnostics`).
- **Expected**: Diagnostics drawer toolbar, search input, count badges, level filter buttons, log tree, and log detail panel render correctly.
- **Result**: PASS

### Scenario 2: Severity Level Filtering
- **Step**: Click level filter buttons (`Info`, `Warning`, `Error`, `Debug`, `All`).
- **Expected**: Log tree entries filter dynamically based on selected severity level filter. Count badges accurately reflect total entries per level.
- **Result**: PASS

### Scenario 3: Text Search Query Filtering
- **Step**: Type query string into `SearchInput`.
- **Expected**: Log tree filters rows matching message or source.
- **Result**: PASS

### Scenario 4: Click & Double-Click Source Navigation
- **Step**: Activate/double-click log entry with source `res://app/main_window.gd:42`.
- **Expected**: `source_navigated` signal is emitted with parsed path `res://app/main_window.gd` and line number `42`. Status bar displays navigation status message.
- **Result**: PASS

### Scenario 5: Clear and Export Operations
- **Step**: Click `Clear` and `Export` buttons.
- **Expected**: `Clear` empties DiagnosticsService log entries and resets UI tree/counts. `Export` returns formatted log string and copies to clipboard.
- **Result**: PASS

### Scenario 6: Dock Layout & Command Toggle
- **Step**: Press `Ctrl+Shift+D` or run `View: Toggle Diagnostics Drawer`.
- **Expected**: `panel_diagnostics` dock panel toggles visibility in main window.
- **Result**: PASS
