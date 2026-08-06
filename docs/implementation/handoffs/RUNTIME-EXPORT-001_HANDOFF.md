# RUNTIME-EXPORT-001 Handoff — Export and Godot Consumer Runtime

## Result

IMPLEMENTED_UNVERIFIED. Batch export is user-reachable, and native Godot export
now serializes a runtime mapping used entirely by the portable addon. The
consumer player builds runtime nodes without authoring dependencies and exposes
appearance persistence, import reports, and debug data.

## Verification Boundary

`QA-EXP-BATCH-001` owns independent batch/cancel/open-artifact acceptance.
`QA-GDT-001` owns a clean-consumer end-to-end review.
