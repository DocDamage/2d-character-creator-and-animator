# Release Acceptance Evidence

## Task ID

`QA-REL-001`

## Status

IN_PROGRESS. The Windows package has been built and launched from a fresh
Windows temporary folder. The documented interactive smoke workflow on a clean
Windows machine remains required before this task can be accepted.

## Evidence

- `Modular2DCharacterStudio.exe` is a 64-bit Windows PE artifact with its
  matching `.pck`; package hashes are retained in `RELEASE-001/test-results.txt`.
- A copied package launched with `--headless --quit` from a fresh Windows temp
  folder and returned exit status 0, demonstrating no authoring-project path is
  required for startup.
- Exported startup diagnostics verify packaged resources instead of reporting
  missing development-only `docs` and `editor_plugins` directories.
- Launcher actions now hand off to the main editor workspace after a project is
  created or opened; the regression is covered by the automated suite.
- Editor docks are grouped into labeled tabs; workspace selection focuses the
  corresponding authoring tab instead of displaying all tools at once.
- The six samples, manuals, preflight, and clean runtime-consumer fixture pass
  automated checks; those are necessary evidence but not a substitute for the
  final interactive release smoke sequence.
