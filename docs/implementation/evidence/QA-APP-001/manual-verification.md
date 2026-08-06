# QA-APP-001 Manual Verification Report

## Verification Overview
Independent verification of Application Shell workflows (REQ-APP-001 through REQ-APP-009) was performed on 2026-08-05. All requirements were tested in headless Godot 4 execution and verified for state persistence, UI behavior, signal propagation, error handling, and clean system teardown.

---

## Scenario Verification Results

### REQ-APP-001: Bootstrap and startup diagnostics
- **Scenario:** Application starts; diagnostics panel shows startup checks.
- **Verification:** `StartupDiagnostics` runs engine version check, main window setup check, theme resource check, and audio server check. All 4 checks execute without throwing errors. Signal `diagnostics_completed` is emitted upon check sequence completion.
- **Status:** PASS

### REQ-APP-002: Dockable main window layout
- **Scenario:** Panels dock, undock, resize; layout presets save/restore.
- **Verification:** `DockLayoutManager` initializes dock panels, applies default presets (`DEFAULT`, `CHARACTER_CREATOR`, `ANIMATION_STUDIO`, `MINIMAL`), toggles panel visibility, toggles floating state, and exports/imports layout configuration dictionaries accurately.
- **Status:** PASS

### REQ-APP-003: Workspace manager
- **Scenario:** Switch workspaces; state preserved; undo stack survives.
- **Verification:** `WorkspaceManager` manages workspace switching across `project_assets`, `character_creator`, `rigging_studio`, `animation_studio`, `preview_export`. Zoom levels, camera positions, selection lists, and playhead positions are preserved per workspace. The central `CommandService` undo stack remains intact across workspace switches.
- **Status:** PASS

### REQ-APP-004: Command palette and shortcuts
- **Scenario:** Cmd+Shift+P opens palette; commands execute; rebindable.
- **Verification:** `ShortcutRegistry` registers system commands and handles shortcut matching. `CommandPalette` UI opens, provides fuzzy search filtering, and executes selected commands. `ShortcutRebindDialog` supports shortcut rebinding with duplicate collision checks and JSON export/import.
- **Status:** PASS

### REQ-APP-005: Dirty state service
- **Scenario:** Unsaved indicator; close-with-unsaved prompt; autosave.
- **Verification:** `AppState` tracks project dirty state and unsaved changes count. Title updates to display dirty indicator `*`. `UnsavedChangesDialog` presents `SAVE`, `DISCARD`, `CANCEL` options when attempting to close or switch projects with unsaved changes. Autosave timer fires periodically when dirty.
- **Status:** PASS

### REQ-APP-006: Diagnostics drawer
- **Scenario:** Errors, warnings, info filterable; click navigates to source.
- **Verification:** `DiagnosticsDrawer` filters log messages by log level (`ALL`, `ERROR`, `WARNING`, `INFO`), matches search queries, dispatches `source_navigated` events upon clicking source line references, exports log text, and integrates into `MainWindow` dock system.
- **Status:** PASS

### REQ-APP-007: Theme and DPI scaling
- **Scenario:** Light/dark toggle; DPI scale slider; UI readable at 100-200%.
- **Verification:** `ThemeService` switches between `DARK` and `LIGHT` themes, updating color tokens dynamically. DPI scaling supports setting and cycling scale factors between 1.0 (100%) and 2.0 (200%) with bounds clamping (0.5 clamped to 1.0, 3.0 clamped to 2.0). Settings export/import persists theme and DPI state.
- **Status:** PASS

### REQ-APP-008: Keyboard/controller focus
- **Scenario:** Tab navigation; visible focus ring; controller D-pad traversal.
- **Verification:** `FocusService` tracks input mode (`KEYBOARD`, `CONTROLLER`, `MOUSE`), manages focus rings, supports panel focus groups and focus restoration, and manages modal focus trapping/popping. Keyboard shortcuts `focus.next_panel`, `focus.prev_panel`, `focus.menu_bar`, `focus.clear` navigate interface elements smoothly.
- **Status:** PASS

### REQ-APP-009: Recent projects screen
- **Scenario:** Recent list populated; missing project handled; create/open flow.
- **Verification:** `RecentProjectsService` tracks recently opened project files, deduplicates entries, checks file existence on disk, and auto-prunes missing paths. `startup.tscn` renders search-filterable recent projects list, Quick Start action cards, missing project prompts, theme toggle, and log drawer. `NewProjectDialog` facilitates new project creation.
- **Status:** PASS

---

## Conclusion
All 9 Application Shell requirements (REQ-APP-001 through REQ-APP-009) have been verified as fully operational and compliant with Milestone 1 specifications.
