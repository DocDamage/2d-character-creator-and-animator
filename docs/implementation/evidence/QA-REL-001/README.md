# Release Acceptance Evidence

## Task ID

`QA-REL-001`

## Status

IN_PROGRESS. Fresh portable and embedded Windows candidates pass automated
build, structure, checksum, startup, regression, and governance verification.
The documented interactive smoke workflow on a clean Windows machine remains
required before this task can be accepted.

## Evidence

- `PaperQuestCharacterStudio.exe` is a 64-bit Windows PE artifact with its
  matching `.pck`; the portable ZIP and single-file executable hashes are
  retained in `test-results.txt`.
- A copied package launched with `--headless --quit` from a fresh Windows temp
  folder and returned exit status 0, demonstrating no authoring-project path is
  required for startup.
- Exported startup diagnostics verify packaged resources instead of reporting
  missing development-only `docs` and `editor_plugins` directories.
- Launcher actions now hand off to the main editor workspace after a project is
  created or opened; the regression is covered by the automated suite.
- Editor docks are grouped into labeled tabs; workspace selection focuses the
  corresponding authoring tab instead of displaying all tools at once.
- The 556-assertion suite, seven focused LPC runners, governance gates, six
  samples, manuals, preflight, and clean runtime-consumer fixture pass
  automated checks; those are necessary evidence but not a substitute for the
  final interactive release smoke sequence.
