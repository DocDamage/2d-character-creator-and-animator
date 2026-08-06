# Unit test for Startup bootstrap script and diagnostics sequence
# Validates APP-001 requirements under engine runtime.
extends Node

const STARTUP_SCENE_PATH := "res://app/bootstrap/startup.tscn"

func run_tests() -> Dictionary:
	var results := {"passed": 0, "failed": 0, "errors": []}

	print("[TEST 5] Startup script instantiation & diagnostic sequence...")
	var startup_packed := ResourceLoader.load(STARTUP_SCENE_PATH) as PackedScene
	if startup_packed == null:
		results["failed"] += 1
		results["errors"].append("Failed to load startup scene from: " + STARTUP_SCENE_PATH)
		return results

	var startup_node := startup_packed.instantiate()
	if startup_node == null:
		results["failed"] += 1
		results["errors"].append("Failed to instantiate startup scene node.")
		return results

	# Add to tree to trigger _ready lifecycle
	add_child(startup_node)

	# Verify startup completion state
	if startup_node.is_startup_complete():
		print("  PASS: Startup sequence reported completion successfully.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Startup sequence did not complete successfully.")

	# Verify total checks count
	var total_checks: int = startup_node.get_total_checks_count()
	var passed_checks: int = startup_node.get_passed_checks_count()
	var packaged_structure: Dictionary = StartupDiagnostics.validate_structure(true)
	if total_checks == 5 and passed_checks == 5 and packaged_structure.get("valid", false):
		print("  PASS: All 5 startup diagnostics and packaged resource checks passed (%d/%d)." % [passed_checks, total_checks])
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Expected valid source/package startup checks, got %d/%d and %s." % [passed_checks, total_checks, str(packaged_structure)])

	# Verify zero startup errors
	var startup_errors: Array[String] = startup_node.get_startup_errors()
	if startup_errors.is_empty():
		print("  PASS: Zero startup errors reported.")
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("Unexpected startup errors: " + str(startup_errors))

	# Verify DiagnosticsService contains startup entries
	var startup_logs := DiagnosticsService.get_filtered_entries()
	if not startup_logs.is_empty():
		print("  PASS: DiagnosticsService recorded %d diagnostic entries." % startup_logs.size())
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("DiagnosticsService contains no logged entries after startup.")

	startup_node.queue_free()
	return results
