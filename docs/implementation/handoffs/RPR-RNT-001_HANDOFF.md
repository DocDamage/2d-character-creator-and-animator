# RPR-RNT-001 Handoff — Make the distributable runtime import plugin self-contained

## Thread Identity

- Task ID: RPR-RNT-001
- Thread type: REPAIR
- Status: ACCEPTED_BY_QA-RNT-001
- Date: 2026-08-05

## Finding

The addon plugin preloaded `res://runtime_plugin/...`, which is an authoring
project path and is absent in a clean consumer project.

## Repair

- Added portable package, importer, editor-importer, state-machine, and rule
  evaluator scripts beneath `addons/modular_character_runtime/runtime/`.
- Switched the addon plugin to its portable editor importer.
- Expanded the external clean-consumer test to cover two-bone IK and state
  setup as well as resource loading, facing, and equipment.

## Automated Tests

`godot --headless --path . --scene tests/test_runner.tscn` reports
`451 PASS, 0 FAIL`.

## Remaining Work

`QA-RNT-001` accepted the repaired consumer plugin and marked the legacy
runtime requirements verified. Broader master-plan `GDT-*` work remains.
