# Startup Workspace Handoff — Resolved

## Observation

On Windows, selecting **New Project** created the project file and added it to
Recent Projects but left the user on the startup screen.

## Cause and resolution

The startup workflow updated `AppState` without changing to the main editor
scene. Startup now requests a workspace transition for every successful New,
Open, Open Sample, and Continue Last action, then defers the scene change until
the dialog callback has completed.

## Verification

- Full regression: 496 PASS, 0 FAIL.
- The recent-projects test asserts that project creation requests the editor
  workspace after `AppState` is loaded.
- Rebuilt Windows package: `Modular2DCharacterStudio.exe` with its matching
  `.pck` listed in `../test-results.txt`.

Interactive clean-machine smoke verification remains tracked by `QA-REL-001`.
