# Test Diagnostics Drawer — Unit tests for DiagnosticsDrawer UI component and integration
extends Node

const DiagDrawerScript = preload("res://core/diagnostics/diagnostics_drawer.gd")
const DiagDrawerScene = preload("res://core/diagnostics/diagnostics_drawer.tscn")
const MainWindowScene = preload("res://app/shared_ui/main_window.tscn")

func run_all() -> Dictionary:
	print("[TEST 10] Diagnostics Drawer UI & Integration...")
	var passes := 0
	var fails := 0

	# Test 1: Instantiation and Default State
	var drawer: Control = DiagDrawerScene.instantiate()
	add_child(drawer)
	if drawer != null and drawer.get_script() == DiagDrawerScript:
		print("  PASS: DiagnosticsDrawer instantiated successfully.")
		passes += 1
	else:
		printerr("  FAIL: DiagnosticsDrawer failed to instantiate.")
		fails += 1

	# Test 2: Level Filtering
	if DiagnosticsService != null:
		DiagnosticsService.clear()
		DiagnosticsService.info("Info msg 1", "TestSource:10")
		DiagnosticsService.warn("Warn msg 1", "TestSource:20")
		DiagnosticsService.error("Error msg 1", "TestSource:30")
		DiagnosticsService.debug("Debug msg 1", "TestSource:40")

		drawer.call("set_level_filter", [4, 5]) # Error only
		var err_entries: Array[Dictionary] = DiagnosticsService.get_filtered_entries()
		if err_entries.size() == 1 and err_entries[0]["message"] == "Error msg 1":
			print("  PASS: Level filter correctly restricts entries to Error.")
			passes += 1
		else:
			printerr("  FAIL: Level filter failed to restrict entries.")
			fails += 1

		drawer.call("set_level_filter", [0, 1, 2, 3, 4, 5]) # All
		var all_entries: Array[Dictionary] = DiagnosticsService.get_filtered_entries()
		if all_entries.size() == 4:
			print("  PASS: Level filter ALL includes all 4 entries.")
			passes += 1
		else:
			printerr("  FAIL: Level filter ALL expected 4 entries, got %d" % all_entries.size())
			fails += 1

	# Test 3: Search Query Filtering
	drawer.call("set_search_query", "Warn msg")
	var matched: bool = drawer.call("_matches_search", {"message": "Warn msg 1", "source": "TestSource"})
	var unmatched: bool = drawer.call("_matches_search", {"message": "Info msg 1", "source": "TestSource"})
	if matched and not unmatched:
		print("  PASS: Search query matching functions correctly.")
		passes += 1
	else:
		printerr("  FAIL: Search query matching failed.")
		fails += 1
	drawer.call("set_search_query", "")

	# Test 4: Source Navigation Signal Emission
	var nav_result := {"source": "", "line": -1}
	drawer.connect("source_navigated", func(src: String, line: int):
		nav_result["source"] = src
		nav_result["line"] = line
	)
	var test_entry := {"level": 4, "level_name": "error", "message": "Test error", "source": "res://app/main.gd:42", "timestamp": 1000.0, "frame": 1}
	drawer.call("navigate_to_source_for_entry", test_entry)
	if nav_result["source"] == "res://app/main.gd" and nav_result["line"] == 42:
		print("  PASS: source_navigated signal dispatched with source and line.")
		passes += 1
	else:
		printerr("  FAIL: source_navigated signal payload invalid: %s:%d" % [nav_result["source"], nav_result["line"]])
		fails += 1


	# Test 5: Clear and Export Functions
	if DiagnosticsService != null:
		var export_text: String = drawer.call("export_logs") as String
		if "Error msg 1" in export_text:
			print("  PASS: Log export generated valid log text.")
			passes += 1
		else:
			printerr("  FAIL: Log export missing expected entry.")
			fails += 1

		drawer.call("clear_logs")
		if DiagnosticsService.get_count() == 0:
			print("  PASS: Clear logs emptied DiagnosticsService entries.")
			passes += 1
		else:
			printerr("  FAIL: Clear logs failed to reset entries count.")
			fails += 1

	drawer.queue_free()

	# Test 6: MainWindow Dock Integration & Command Registry
	var main_win: Control = MainWindowScene.instantiate()
	add_child(main_win)
	var diag_panel: Control = main_win.call("get_panel", "panel_diagnostics") as Control
	if diag_panel != null:
		print("  PASS: MainWindow contains panel_diagnostics dock panel.")
		passes += 1
	else:
		printerr("  FAIL: MainWindow panel_diagnostics missing.")
		fails += 1

	if ShortcutRegistry != null and ShortcutRegistry.has_command("view.toggle_diagnostics"):
		print("  PASS: view.toggle_diagnostics command registered in ShortcutRegistry.")
		passes += 1
	else:
		printerr("  FAIL: view.toggle_diagnostics missing from ShortcutRegistry.")
		fails += 1

	main_win.queue_free()

	return {"pass": passes, "fail": fails}
