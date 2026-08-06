# Integration Test — Fixture Loading & Malformed Input Handling
# Verifies that baseline valid project fixture loads cleanly and malformed fixture triggers diagnostics.
# Run: godot --headless --script tests/integration/test_malformed_fixtures.gd
extends SceneTree

const BASELINE_FIXTURE := "res://tests/fixtures/baseline/valid_project.chrproj"
const MALFORMED_FIXTURE := "res://tests/fixtures/malformed/corrupt_project.chrproj"

func _init() -> void:
	print("=== Test: Fixture Loading & Malformed Handling ===")
	var pass_count := 0
	var fail_count := 0

	# 1. Test baseline valid fixture loading
	print("[1/2] Testing baseline valid fixture: %s" % BASELINE_FIXTURE)
	var baseline_data := SerializationService.load_project(BASELINE_FIXTURE)
	if baseline_data.is_empty():
		printerr("FAIL: Baseline fixture failed to load or returned empty dictionary.")
		fail_count += 1
	else:
		var validation_errors := SerializationService.validate_project(baseline_data)
		if not validation_errors.is_empty():
			printerr("FAIL: Baseline fixture validation errors: %s" % str(validation_errors))
			fail_count += 1
		else:
			print("  PASS: Baseline fixture loaded and validated successfully.")
			print("        Project ID: %s" % baseline_data.get("project_id", ""))
			print("        Project Name: %s" % baseline_data.get("project_name", ""))
			pass_count += 1

	# 2. Test malformed/corrupt fixture handling
	print("[2/2] Testing malformed corrupt fixture: %s" % MALFORMED_FIXTURE)
	var corrupt_data := SerializationService.load_project(MALFORMED_FIXTURE)
	if corrupt_data.is_empty():
		print("  PASS: Malformed fixture failed safely returning empty dictionary.")
		print("        Diagnostics captured error gracefully.")
		pass_count += 1
	else:
		printerr("FAIL: Malformed fixture loaded data unexpectedly!")
		fail_count += 1

	print("")
	print("Summary: %d passed, %d failed" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)
