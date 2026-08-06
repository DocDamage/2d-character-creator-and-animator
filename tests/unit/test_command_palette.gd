# Unit test suite for ShortcutRegistry, CommandPalette UI, and ShortcutRebindDialog
extends Node

const CommandPaletteScript = preload("res://app/commands/command_palette.gd")
const ShortcutRebindDialogScript = preload("res://app/commands/shortcut_rebind_dialog.gd")

var _executed_test_cmd: bool = false

func run_all_tests() -> bool:
	print("[TEST 8] Command Palette & Shortcut Registry workflows...")
	var all_passed := true

	all_passed = _test_registry_registration_and_lookup() and all_passed
	all_passed = _test_registry_search_filtering() and all_passed
	all_passed = _test_registry_execution_and_signals() and all_passed
	all_passed = _test_shortcut_matching_and_rebinding() and all_passed
	all_passed = _test_bindings_export_and_import() and all_passed
	all_passed = _test_command_palette_ui_behavior() and all_passed
	all_passed = _test_shortcut_rebind_dialog_ui_behavior() and all_passed

	return all_passed


func _test_registry_registration_and_lookup() -> bool:
	if ShortcutRegistry == null:
		print("  FAIL: ShortcutRegistry autoload unavailable.")
		return false

	var ok := ShortcutRegistry.register_command("test.sample_cmd", "Sample Command", "Testing", "Ctrl+D", _sample_callback, ["test", "sample"])
	if not ok:
		print("  FAIL: Failed to register test command.")
		return false

	if not ShortcutRegistry.has_command("test.sample_cmd"):
		print("  FAIL: has_command returned false for registered command.")
		return false

	var cmd: Dictionary = ShortcutRegistry.get_command("test.sample_cmd")
	if cmd.get("title", "") != "Sample Command" or cmd.get("shortcut", "") != "Ctrl+D":
		print("  FAIL: get_command returned unexpected data.")
		return false

	print("  PASS: ShortcutRegistry command registration and lookup verified.")
	return true


func _test_registry_search_filtering() -> bool:
	var results := ShortcutRegistry.search_commands("Sample")
	if results.size() == 0:
		print("  FAIL: search_commands by title returned 0 results.")
		return false

	results = ShortcutRegistry.search_commands("Testing")
	if results.size() == 0:
		print("  FAIL: search_commands by category returned 0 results.")
		return false

	results = ShortcutRegistry.search_commands("non_existent_query_xyz")
	if results.size() != 0:
		print("  FAIL: search_commands returned results for non-matching query.")
		return false

	print("  PASS: ShortcutRegistry search filtering verified.")
	return true


func _test_registry_execution_and_signals() -> bool:
	_executed_test_cmd = false
	var executed := ShortcutRegistry.execute_command("test.sample_cmd")
	if not executed or not _executed_test_cmd:
		print("  FAIL: execute_command failed or callback not executed.")
		return false

	print("  PASS: ShortcutRegistry command execution verified.")
	return true


func _test_shortcut_matching_and_rebinding() -> bool:
	var rebound := ShortcutRegistry.rebind_shortcut("test.sample_cmd", "Ctrl+Alt+D")
	if not rebound:
		print("  FAIL: rebind_shortcut failed.")
		return false

	var cmd := ShortcutRegistry.get_command("test.sample_cmd")
	if cmd.get("shortcut", "") != "Ctrl+Alt+D":
		print("  FAIL: Rebound shortcut value incorrect.")
		return false

	var found := ShortcutRegistry.find_command_by_shortcut("Ctrl+Alt+D")
	if found.get("id", "") != "test.sample_cmd":
		print("  FAIL: find_command_by_shortcut failed to locate command.")
		return false

	ShortcutRegistry.reset_shortcut("test.sample_cmd")
	cmd = ShortcutRegistry.get_command("test.sample_cmd")
	if cmd.get("shortcut", "") != "Ctrl+D":
		print("  FAIL: reset_shortcut failed to restore default shortcut.")
		return false

	print("  PASS: Shortcut matching and rebinding verified.")
	return true


func _test_bindings_export_and_import() -> bool:
	ShortcutRegistry.rebind_shortcut("test.sample_cmd", "Ctrl+Shift+K")
	var exported := ShortcutRegistry.export_bindings()
	if not exported.has("test.sample_cmd") or exported["test.sample_cmd"] != "Ctrl+Shift+K":
		print("  FAIL: export_bindings failed to export custom shortcut.")
		return false

	ShortcutRegistry.reset_all_shortcuts()
	if ShortcutRegistry.get_command("test.sample_cmd").get("shortcut", "") != "Ctrl+D":
		print("  FAIL: reset_all_shortcuts failed.")
		return false

	var imported := ShortcutRegistry.import_bindings(exported)
	if not imported or ShortcutRegistry.get_command("test.sample_cmd").get("shortcut", "") != "Ctrl+Shift+K":
		print("  FAIL: import_bindings failed to apply exported shortcuts.")
		return false

	ShortcutRegistry.reset_shortcut("test.sample_cmd")
	print("  PASS: Shortcut bindings export and import verified.")
	return true


func _test_command_palette_ui_behavior() -> bool:
	var palette_scene: PackedScene = load("res://app/commands/command_palette.tscn")
	if palette_scene == null:
		print("  FAIL: Failed to load command_palette.tscn.")
		return false

	var palette: Control = palette_scene.instantiate() as Control
	add_child(palette)

	palette.call("open")
	if not (palette.call("is_open") as bool) or not palette.visible:
		print("  FAIL: CommandPalette failed to open.")
		palette.queue_free()
		return false

	palette.call("refresh_results", "Sample")
	var count: int = palette.call("get_filtered_count") as int
	if count < 1:
		print("  FAIL: CommandPalette search filtering failed to find sample command.")
		palette.queue_free()
		return false

	var cid: String = palette.call("get_selected_command_id") as String
	if cid.is_empty():
		print("  FAIL: CommandPalette get_selected_command_id returned empty.")
		palette.queue_free()
		return false

	palette.call("close")
	if (palette.call("is_open") as bool) or palette.visible:
		print("  FAIL: CommandPalette failed to close.")
		palette.queue_free()
		return false

	palette.queue_free()
	print("  PASS: CommandPalette UI behavior verified.")
	return true


func _test_shortcut_rebind_dialog_ui_behavior() -> bool:
	var rebind_scene: PackedScene = load("res://app/commands/shortcut_rebind_dialog.tscn")
	if rebind_scene == null:
		print("  FAIL: Failed to load shortcut_rebind_dialog.tscn.")
		return false

	var dialog: Control = rebind_scene.instantiate() as Control
	add_child(dialog)

	dialog.call("open_for_command", "test.sample_cmd")
	if not dialog.visible:
		print("  FAIL: ShortcutRebindDialog failed to open.")
		dialog.queue_free()
		return false

	dialog.call("close")
	if dialog.visible:
		print("  FAIL: ShortcutRebindDialog failed to close.")
		dialog.queue_free()
		return false

	dialog.queue_free()
	ShortcutRegistry.unregister_command("test.sample_cmd")
	print("  PASS: ShortcutRebindDialog UI behavior verified.")
	return true


func _sample_callback() -> void:
	_executed_test_cmd = true
