# Export Artifact Verification Evidence

## Task ID

`QA-EXP-001`

## Status

VERIFIED. The legacy export requirements have been accepted using readers and
decoders outside the exporter implementations. The later master-plan export
engine work (`EXP-009` through `EXP-012`) remains separately scoped.

## Evidence

- `tests/integration/test_export_artifact_validation.gd` creates a fresh set
  of package, atlas, PNG, WebP, JSON/XML spritesheet, GIF, MP4, WebM, `.tres`,
  and `.tscn` artifacts.
- Runtime packages are loaded with the package reader; PNG and WebP artifacts
  are loaded as images; JSON and XML manifests are parsed/read; and atlas
  layouts are re-packed to prove deterministic placement.
- The test verifies alpha trimming source rectangles, padding, edge extrusion,
  and reopened atlas pixels.
- GIF, MP4, and WebM files are checked for their container signatures and
  decoded with `ffprobe`, which validates a video stream at the expected size.
- Native Godot resources and scenes are reloaded and instantiated; the
  separate clean-consumer test loads the same native artifacts in a project
  containing only the runtime addon.
- Full suite result: `452 PASS, 0 FAIL`, with no engine, script, warning,
  loader, or clean-consumer diagnostics. LOC and stub scans pass.
