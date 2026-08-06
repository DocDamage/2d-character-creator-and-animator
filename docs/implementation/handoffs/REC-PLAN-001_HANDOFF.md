# REC-PLAN-001 Handoff — Reconcile master-plan tasks and establish clean-consumer fixture

## Thread Identity

- Task ID: REC-PLAN-001
- Thread type: IMPLEMENTATION
- Status: IMPLEMENTED_UNVERIFIED
- Date: 2026-08-05

## Scope

- Reconcile the former ledger numbering with the authoritative master plan.
- Make native Godot resources resolve against the distributable runtime addon.
- Add a genuine isolated consumer-project regression test.
- Repair transform snapping at drag commit and selective bone inheritance.

## Work Performed

- Added `MASTER_PLAN_RECONCILIATION.md` and cross-references from the ledger,
  traceability matrix, and master plan.
- Added a portable `CharacterPlayer2D` and resource carrier beneath the
  distributable addon. `GodotResourceExporter` now serializes those scripts,
  and can bind exported scene references to a consumer-relative resource path.
- Added a clean-consumer fixture and test. It launches a distinct Godot process
  with only the runtime addon plus generated outputs.
- Persisted active transform snap settings through `TransformGizmo.finish_drag`
  and made `BoneManager` honour per-channel inheritance flags.

## Acceptance Criteria

- PASS: Reconciliation distinguishes runtime core from missing authoring work.
- PASS: Generated native package loads in a clean runtime-only project.
- PASS: Drag snapping persists at commit.
- PASS: Position, rotation, and scale inheritance can be independently disabled.
- PASS: Full test suite has 450 passes.

## Remaining Work

- Run independent `QA-WPN-META-001`, `QA-GRID-001`, `QA-EXP-001`, and
  `QA-RNT-001`; do not mark their legacy requirements verified from this task.
- Add each later master-plan task row before its implementation starts.

## Next Task Recommendation

- Task ID: QA-GRID-001
- Thread type: VERIFICATION
- Reason: It is the first independent review of the facing-grid runtime core
  and establishes the authoritative parity findings for Phase 1.
