# Unit Test Suite — Keyboard & Controller Focus Framework (APP-008)
extends Node

const MainWindowScript = preload("res://app/shared_ui/main_window.gd")
const FocusServiceScript = preload("res://app/shared_ui/focus_service.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func run_all_tests() -> bool:
	print("[TEST 12] Keyboard & Controller Focus Framework Workflows...")
	_pass_count = 0
	_fail_count = 0

	_test_autoload_availability()
	_test_input_mode_management()
	_test_focus_tracking_and_signals()
	_test_focus_groups_and_cycling()
	_test_focus_memory()
	_test_focus_trap_modal()
	_test_settings_export_import()
	_test_shortcut_commands_integration()
	_test_main_window_integration()

	return _fail_count == 0

func _assert(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: " + message)
	else:
		_fail_count += 1
		printerr("  FAIL: " + message)

func _test_autoload_availability() -> void:
	_assert(FocusService != null, "FocusService autoload is available.")
	if FocusService != null:
		_assert(FocusService.get_input_mode() == FocusServiceScript.InputMode.KEYBOARD, "FocusService initializes in KEYBOARD input mode.")
		_assert(FocusService.focus_ring_enabled == true, "Focus ring is enabled by default.")

func _test_input_mode_management() -> void:
	if FocusService == null: return
	FocusService.set_input_mode(FocusServiceScript.InputMode.KEYBOARD)
	var received_mode := [-1]
	var mode_cb := func(m: int): received_mode[0] = m
	FocusService.input_mode_changed.connect(mode_cb)
	
	FocusService.set_input_mode(FocusServiceScript.InputMode.CONTROLLER)
	_assert(FocusService.get_input_mode() == FocusServiceScript.InputMode.CONTROLLER, "Input mode set to CONTROLLER.")
	_assert(FocusService.get_input_mode_name() == "CONTROLLER", "Input mode name returns 'CONTROLLER'.")
	_assert(received_mode[0] == FocusServiceScript.InputMode.CONTROLLER, "input_mode_changed signal dispatched.")

	FocusService.set_input_mode(FocusServiceScript.InputMode.MOUSE)
	_assert(FocusService.get_input_mode() == FocusServiceScript.InputMode.MOUSE, "Input mode set to MOUSE.")
	_assert(FocusService.get_input_mode_name() == "MOUSE", "Input mode name returns 'MOUSE'.")

	FocusService.set_input_mode(FocusServiceScript.InputMode.KEYBOARD)
	FocusService.input_mode_changed.disconnect(mode_cb)

func _test_focus_tracking_and_signals() -> void:
	if FocusService == null: return
	FocusService.current_focused_control = null
	FocusService.previous_focused_control = null
	var container := Control.new()
	var btn1 := Button.new()
	var btn2 := Button.new()
	btn1.focus_mode = Control.FOCUS_ALL
	btn2.focus_mode = Control.FOCUS_ALL
	container.add_child(btn1)
	container.add_child(btn2)
	add_child(container)

	var last_new: Array[Control] = [null]
	var last_old: Array[Control] = [null]
	var focus_cb := func(n: Control, o: Control):
		last_new[0] = n
		last_old[0] = o
	FocusService.focus_changed.connect(focus_cb)

	FocusService.call("_on_gui_focus_changed", btn1)
	_assert(FocusService.current_focused_control == btn1, "current_focused_control updated to btn1.")
	
	FocusService.call("_on_gui_focus_changed", btn2)
	_assert(FocusService.current_focused_control == btn2, "current_focused_control updated to btn2.")
	_assert(FocusService.previous_focused_control == btn1, "previous_focused_control updated to btn1.")
	_assert(last_new[0] == btn2 and last_old[0] == btn1, "focus_changed signal emitted with correct controls.")

	FocusService.focus_changed.disconnect(focus_cb)
	container.queue_free()

func _test_focus_groups_and_cycling() -> void:
	if FocusService == null: return
	var root := Control.new()
	var g1 := Control.new()
	var g2 := Control.new()
	var btn_g1 := Button.new()
	var btn_g2 := Button.new()
	btn_g1.focus_mode = Control.FOCUS_ALL
	btn_g2.focus_mode = Control.FOCUS_ALL
	g1.add_child(btn_g1)
	g2.add_child(btn_g2)
	root.add_child(g1)
	root.add_child(g2)
	add_child(root)

	FocusService.register_focus_group("group_a", g1)
	FocusService.register_focus_group("group_b", g2)
	_assert(FocusService.get_registered_focus_groups().has("group_a"), "group_a registered.")
	_assert(FocusService.get_registered_focus_groups().has("group_b"), "group_b registered.")

	var focused_a := FocusService.focus_group("group_a")
	_assert(focused_a, "focus_group('group_a') succeeded.")
	_assert(btn_g1.has_focus() or FocusService.current_focused_control == btn_g1, "Focused control inside group_a.")

	FocusService.unregister_focus_group("group_a")
	FocusService.unregister_focus_group("group_b")
	root.queue_free()

func _test_focus_memory() -> void:
	if FocusService == null: return
	var root := Control.new()
	var panel := Control.new()
	var b1 := Button.new()
	var b2 := Button.new()
	b1.focus_mode = Control.FOCUS_ALL
	b2.focus_mode = Control.FOCUS_ALL
	panel.add_child(b1)
	panel.add_child(b2)
	root.add_child(panel)
	add_child(root)

	FocusService.register_focus_group("mem_panel", panel)
	b2.grab_focus()
	_assert(b2.has_focus(), "b2 manually focused in mem_panel.")

	FocusService.clear_focus()
	_assert(get_viewport().gui_get_focus_owner() == null, "Focus cleared.")

	var focused := FocusService.focus_group("mem_panel")
	_assert(focused, "focus_group restored focus to mem_panel.")
	_assert(b2.has_focus(), "Focus restored to last focused widget (b2) in panel.")

	FocusService.unregister_focus_group("mem_panel")
	root.queue_free()

func _test_focus_trap_modal() -> void:
	if FocusService == null: return
	var root := Control.new()
	var main_btn := Button.new()
	var modal := Control.new()
	var modal_btn := Button.new()
	main_btn.focus_mode = Control.FOCUS_ALL
	modal_btn.focus_mode = Control.FOCUS_ALL
	root.add_child(main_btn)
	modal.add_child(modal_btn)
	root.add_child(modal)
	add_child(root)

	main_btn.grab_focus()
	_assert(main_btn.has_focus(), "main_btn focused before trap.")

	FocusService.push_focus_trap(modal)
	_assert(FocusService.is_focus_trapped(), "is_focus_trapped returns true.")
	_assert(FocusService.get_active_focus_trap() == modal, "active focus trap matches modal node.")
	_assert(modal_btn.has_focus(), "Focus pushed to modal_btn inside modal dialog.")

	FocusService.pop_focus_trap()
	_assert(not FocusService.is_focus_trapped(), "is_focus_trapped returns false after pop.")
	_assert(main_btn.has_focus(), "Focus restored to main_btn after popping trap.")

	root.queue_free()

func _test_settings_export_import() -> void:
	if FocusService == null: return
	FocusService.focus_ring_enabled = true
	FocusService.set_input_mode(FocusServiceScript.InputMode.CONTROLLER)

	var exported := FocusService.export_settings()
	_assert(exported.get("focus_ring_enabled") == true, "Export contains focus_ring_enabled true.")
	_assert(exported.get("input_mode") == FocusServiceScript.InputMode.CONTROLLER as int, "Export contains input_mode CONTROLLER.")

	FocusService.focus_ring_enabled = false
	FocusService.set_input_mode(FocusServiceScript.InputMode.KEYBOARD)

	var imported := FocusService.import_settings(exported)
	_assert(imported, "import_settings returns true for valid dict.")
	_assert(FocusService.focus_ring_enabled == true, "Import restored focus_ring_enabled true.")
	_assert(FocusService.get_input_mode() == FocusServiceScript.InputMode.CONTROLLER, "Import restored input_mode CONTROLLER.")

	FocusService.set_input_mode(FocusServiceScript.InputMode.KEYBOARD)
	_assert(FocusService.import_settings({}) == true, "import_settings handles empty dictionary safely.")

func _test_shortcut_commands_integration() -> void:
	if ShortcutRegistry == null: return
	_assert(ShortcutRegistry.has_command("focus.next_panel"), "focus.next_panel command registered.")
	_assert(ShortcutRegistry.has_command("focus.prev_panel"), "focus.prev_panel command registered.")
	_assert(ShortcutRegistry.has_command("focus.menu_bar"), "focus.menu_bar command registered.")
	_assert(ShortcutRegistry.has_command("focus.clear"), "focus.clear command registered.")

	var executed := ShortcutRegistry.execute_command("focus.next_panel")
	_assert(executed, "Executing focus.next_panel command returned true.")

func _test_main_window_integration() -> void:
	var scene: PackedScene = load("res://app/shared_ui/main_window.tscn")
	if scene == null: return
	var mw := scene.instantiate() as Control
	add_child(mw)
	_assert(mw != null, "MainWindow instantiated for focus integration test.")
	_assert(FocusService.get_registered_focus_groups().has("menu_bar"), "MainWindow registered menu_bar focus group.")
	_assert(FocusService.get_registered_focus_groups().has("panel_assets"), "MainWindow registered panel_assets focus group.")
	mw.queue_free()
