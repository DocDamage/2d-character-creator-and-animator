# Unit tests for Phase 5 state-machine authoring and runtime parity.
extends Node

const ModelScript = preload("res://animation/state_machine/state_machine_authoring_model.gd")
const DefinitionScript = preload("res://animation/state_machine/state_machine_definition.gd")


func run_tests() -> int:
	var model = ModelScript.new()
	var created: bool = model.create("hero_locomotion", "Hero Locomotion")
	var idle_ok: bool = model.add_state("idle", "idle", "Idle", Vector2(20.0, 30.0))
	var run_ok: bool = model.add_state("run", "run", "Run", Vector2(240.0, 30.0))
	model.machine.add_parameter("moving", false, "bool")
	var transition_ok: bool = model.connect_states("idle_to_run", "idle", "run", [{"parameter": "moving", "value": true}], 0.2, -1.0, 2)
	var nested = DefinitionScript.new("run_detail", "Run Detail")
	nested.add_state("entry", "run_detail")
	var nested_ok: bool = model.set_nested_machine("run", nested)
	var preview_ok: bool = model.configure_preview({"idle": 1.0, "run": 1.0}) and model.set_preview_parameter("moving", true)
	var preview: Dictionary = model.preview_tick(0.1)
	var restored = ModelScript.new()
	var round_trip: bool = restored.from_dict(model.to_dict())
	if created and idle_ok and run_ok and transition_ok and nested_ok and preview_ok and preview.get("state_id") == "run" and model.export_runtime().get("states", {}).get("run", {}).get("nested_machine", {}).get("machine_id") == "run_detail" and round_trip and restored.diagnostics().is_empty():
		print("  PASS: STM-001 through STM-004 graph editing, nested machines, preview, and runtime export")
		return 1
	printerr("  FAIL: state-machine authoring model did not preserve graph/runtime behavior")
	return 0
