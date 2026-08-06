# QA-EXP-001 Handoff — Verify legacy export artifacts

## Thread Identity

- Task ID: QA-EXP-001
- Thread type: VERIFICATION
- Status: COMPLETED
- Date: 2026-08-05

## Accepted Behavior

- Runtime packages, deterministic atlas layouts, PNG/WebP sequences, JSON/XML
  spritesheets, GIF, MP4, WebM, and native Godot data/scene exports are emitted
  and reopened successfully.
- The artifact test verifies trim bounds, padding, edge extrusion, actual image
  dimensions, container signatures, and external video decoding.
- Native `.tres`/`.tscn` output is also accepted by the isolated runtime-only
  consumer-project test.

## Automated Results

- Full Godot suite: `452 PASS, 0 FAIL`.
- Focused suite scan: no error, warning, loader, or failure lines.
- LOC and stub scans pass.

## Remaining Scope

This accepts legacy `EXP-001` through `EXP-008`. Master-plan `EXP-009` through
`EXP-012` still own batching, cancellation/progress, a production artifact
validator, and output-opening UX. Full-fidelity Godot mapping remains `GDT-*`
scope.
