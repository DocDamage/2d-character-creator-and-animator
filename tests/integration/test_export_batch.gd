# Integration tests for Phase 6 variant batch export, cancellation, validation, and opening checks.
extends Node

const ControllerScript = preload("res://export/batch/batch_export_controller.gd")
const ValidatorScript = preload("res://export/batch/artifact_validator.gd")


func run_tests() -> int:
	var root := "user://phase6_batch_%d" % Time.get_ticks_usec()
	var controller = ControllerScript.new()
	var character_ok: bool = controller.add_variant("hero", "character", {"project_id": "hero", "parts": ["body"]}, {"display_name": "Hero"})
	var weapon_ok: bool = controller.add_variant("sword", "weapon", {"project_id": "sword", "grips": ["main"]}, {"display_name": "Sword"})
	var progress: Array = []
	var exported: Dictionary = controller.export_all(root, func(done: int, total: int, _result: Dictionary): progress.append([done, total]))
	var validation: Dictionary = controller.validate_results(exported)
	var opened: Dictionary = ValidatorScript.new().verify_openable(root.path_join("hero.chrpack"))
	var cancelling = ControllerScript.new()
	cancelling.add_variant("a", "character", {"project_id": "a"})
	cancelling.add_variant("b", "character", {"project_id": "b"})
	var cancelled: Dictionary = cancelling.export_all(root.path_join("cancelled"), func(_done: int, _total: int, _result: Dictionary): cancelling.request_cancel())
	var restored = ControllerScript.new().from_dict(controller.to_dict())
	if character_ok and weapon_ok and exported.get("success", false) and progress.size() == 2 and validation.get("valid", false) and opened.get("opened", false) and cancelled.get("cancelled", false) and cancelled.get("results", []).size() == 1 and restored.get_variant("sword").get("variant_type") == "weapon":
		print("  PASS: EXP-009 through EXP-012 batch variants report progress, cancel safely, validate artifacts, and open outputs")
		return 1
	printerr("  FAIL: export batch workflow did not finish safely: %s" % str(exported))
	return 0
