# Completion QA Suite — Runs with project autoloads through completion_qa_runner.tscn.
extends Node

const Phase2Script = preload("res://tests/integration/test_weapon_phase2_acceptance.gd")
const CharacterScript = preload("res://tests/integration/test_character_creator.gd")
const MediaScript = preload("res://tests/integration/test_media_authoring.gd")
const BlendScript = preload("res://tests/unit/test_animation_blending.gd")
const StateMachineScript = preload("res://tests/unit/test_state_machine_authoring.gd")
const RuleScript = preload("res://tests/unit/test_rule_graph_authoring.gd")
const LinkedProjectsScript = preload("res://tests/integration/test_linked_projects.gd")
const ExportBatchScript = preload("res://tests/integration/test_export_batch.gd")
const RuntimeMappingScript = preload("res://tests/integration/test_godot_runtime_mapping.gd")
const CleanConsumerScript = preload("res://tests/integration/test_clean_consumer_export.gd")
const QualityScript = preload("res://tests/integration/test_quality_reliability.gd")


func _ready() -> void:
	var checks: Array[Dictionary] = [
		{"ids": "QA-WPN-001, QA-SOL-001, QA-WPA-001", "script": Phase2Script, "expected": 1},
		{"ids": "QA-CHR-001", "script": CharacterScript, "expected": 4},
		{"ids": "QA-GMD-001, QA-MED-001", "script": MediaScript, "expected": 3},
		{"ids": "QA-RUL-001", "script": BlendScript, "expected": 1},
		{"ids": "QA-RUL-001", "script": StateMachineScript, "expected": 1},
		{"ids": "QA-RUL-001", "script": RuleScript, "expected": 1},
		{"ids": "QA-LNK-001", "script": LinkedProjectsScript, "expected": 1},
		{"ids": "QA-EXP-BATCH-001", "script": ExportBatchScript, "expected": 1},
		{"ids": "QA-GDT-001", "script": RuntimeMappingScript, "expected": 1},
		{"ids": "QA-GDT-001", "script": CleanConsumerScript, "expected": 1},
		{"ids": "QA-PRF-001", "script": QualityScript, "expected": 1},
	]
	var failures := 0
	print("=== Completion Plan Scoped QA ===")
	for check in checks:
		var runner: Node = check.script.new()
		print("  RUN: " + str(check.ids))
		var result = runner.run_tests()
		var passed := _matches(result, int(check.expected))
		runner.free()
		if passed:
			print("  PASS: %s (%d expected assertions)" % [check.ids, int(check.expected)])
		else:
			failures += 1
			printerr("  FAIL: %s expected %d passing assertions, got %s" % [check.ids, int(check.expected), str(result)])
	print("=== Completion QA Finished: %d failed ===" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _matches(result, expected: int) -> bool:
	if result is Dictionary:
		return int(result.get("passed", 0)) == expected and int(result.get("failed", 0)) == 0
	return int(result) == expected
