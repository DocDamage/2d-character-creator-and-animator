# Focus Service — Global focus framework manager for keyboard & controller UI navigation
extends Node

signal input_mode_changed(mode: int)
signal focus_changed(new_control: Control, old_control: Control)
signal focus_ring_visibility_changed(is_visible: bool)

enum InputMode { KEYBOARD, CONTROLLER, MOUSE }

const FocusRingScript = preload("res://app/shared_ui/focus_ring_overlay.gd")

var current_input_mode: InputMode = InputMode.KEYBOARD
var current_focused_control: Control = null
var previous_focused_control: Control = null
var focus_ring_enabled: bool = true

var _overlay: Control = null
var _focus_groups: Array[String] = []
var _group_root_nodes: Dictionary = {}
var _last_focused_in_group: Dictionary = {}
var _current_group_index: int = -1
var _focus_trap_stack: Array[Control] = []
var _saved_trap_focus: Array[Control] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	_setup_overlay()
	_update_ring_state()

func _input(event: InputEvent) -> void:
	_detect_input_mode(event)
	_enforce_focus_trap(event)

func get_input_mode() -> InputMode:
	return current_input_mode

func get_input_mode_name() -> String:
	match current_input_mode:
		InputMode.KEYBOARD: return "KEYBOARD"
		InputMode.CONTROLLER: return "CONTROLLER"
		InputMode.MOUSE: return "MOUSE"
		_: return "UNKNOWN"

func set_input_mode(mode: InputMode) -> void:
	current_input_mode = mode
	input_mode_changed.emit(current_input_mode as int)
	_update_ring_state()
	if DiagnosticsService != null:
		DiagnosticsService.info("Focus input mode changed to: " + get_input_mode_name(), "FocusService")

func register_focus_group(group_id: String, root_node: Control) -> void:
	if group_id.is_empty() or root_node == null:
		return
	if not _focus_groups.has(group_id):
		_focus_groups.append(group_id)
	_group_root_nodes[group_id] = root_node

func unregister_focus_group(group_id: String) -> void:
	_focus_groups.erase(group_id)
	_group_root_nodes.erase(group_id)
	_last_focused_in_group.erase(group_id)

func get_registered_focus_groups() -> Array[String]:
	return _focus_groups.duplicate()

func cycle_panel_focus(forward: bool = true) -> bool:
	if _focus_groups.is_empty():
		return false
	if _current_group_index < 0 or _current_group_index >= _focus_groups.size():
		_current_group_index = 0
	else:
		var step := 1 if forward else -1
		_current_group_index = (_current_group_index + step + _focus_groups.size()) % _focus_groups.size()
	var target_group := _focus_groups[_current_group_index]
	return focus_group(target_group)

func focus_group(group_id: String) -> bool:
	if not _group_root_nodes.has(group_id):
		return false
	var root_node: Control = _group_root_nodes[group_id] as Control
	if root_node == null or not root_node.is_inside_tree() or not root_node.is_visible_in_tree():
		return false
	var target: Control = null
	if _last_focused_in_group.has(group_id):
		var saved: Control = _last_focused_in_group[group_id] as Control
		if saved != null and is_instance_valid(saved) and saved.is_inside_tree() and saved.is_visible_in_tree():
			target = saved
	if target == null:
		target = find_first_focusable(root_node)
	if target != null:
		target.grab_focus()
		var idx := _focus_groups.find(group_id)
		if idx >= 0:
			_current_group_index = idx
		return true
	return false

func focus_menu_bar(menu_bar_node: Control = null) -> bool:
	var target := menu_bar_node
	if target == null and _group_root_nodes.has("menu_bar"):
		target = _group_root_nodes["menu_bar"] as Control
	if target != null:
		var focusable := find_first_focusable(target)
		if focusable != null:
			focusable.grab_focus()
			return true
	return false

func clear_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func push_focus_trap(modal_control: Control) -> void:
	if modal_control == null:
		return
	var current_focus := get_viewport().gui_get_focus_owner()
	_saved_trap_focus.append(current_focus)
	_focus_trap_stack.append(modal_control)
	var focusable := find_first_focusable(modal_control)
	if focusable != null:
		focusable.grab_focus()

func pop_focus_trap() -> void:
	if _focus_trap_stack.is_empty():
		return
	_focus_trap_stack.pop_back()
	var restored_focus: Control = _saved_trap_focus.pop_back() if not _saved_trap_focus.is_empty() else null
	if restored_focus != null and is_instance_valid(restored_focus) and restored_focus.is_inside_tree() and restored_focus.is_visible_in_tree():
		restored_focus.grab_focus()

func is_focus_trapped() -> bool:
	return not _focus_trap_stack.is_empty()

func get_active_focus_trap() -> Control:
	return _focus_trap_stack.back() if not _focus_trap_stack.is_empty() else null

func find_first_focusable(node: Node) -> Control:
	if node == null or not is_instance_valid(node):
		return null
	if node is Control:
		var c := node as Control
		if c.visible and c.focus_mode != Control.FOCUS_NONE:
			if c is Button or c is LineEdit or c is TextEdit or c is OptionButton or c is ItemList or c is Tree or c is TabBar or c is Slider or c.get_child_count() == 0:
				return c
	for child in node.get_children():
		var result := find_first_focusable(child)
		if result != null:
			return result
	return null

func export_settings() -> Dictionary:
	return {
		"focus_ring_enabled": focus_ring_enabled,
		"input_mode": current_input_mode as int
	}

func import_settings(data: Dictionary) -> bool:
	if data == null:
		return false
	if data.has("focus_ring_enabled") and data["focus_ring_enabled"] is bool:
		focus_ring_enabled = data["focus_ring_enabled"] as bool
	if data.has("input_mode") and data["input_mode"] is float or data.has("input_mode") and data["input_mode"] is int:
		var m := int(data["input_mode"])
		if m >= 0 and m <= 2:
			set_input_mode(m as InputMode)
	_update_ring_state()
	return true

func _setup_overlay() -> void:
	if _overlay == null:
		_overlay = FocusRingScript.new()
		add_child(_overlay)

func _on_gui_focus_changed(control: Control) -> void:
	previous_focused_control = current_focused_control
	current_focused_control = control
	if control != null:
		_record_group_focus(control)
	if _overlay != null and _overlay.has_method("set_target_control"):
		_overlay.call("set_target_control", control if _should_show_ring() else null)
	focus_changed.emit(current_focused_control, previous_focused_control)

func _record_group_focus(control: Control) -> void:
	for gid in _focus_groups:
		var root: Control = _group_root_nodes.get(gid) as Control
		if root != null and is_instance_valid(root) and root.is_ancestor_of(control):
			_last_focused_in_group[gid] = control
			_current_group_index = _focus_groups.find(gid)
			break

func _detect_input_mode(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed:
			set_input_mode(InputMode.KEYBOARD)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		set_input_mode(InputMode.CONTROLLER)
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 4.0):
		set_input_mode(InputMode.MOUSE)

func _enforce_focus_trap(event: InputEvent) -> void:
	if _focus_trap_stack.is_empty():
		return
	var active_trap := _focus_trap_stack.back() as Control
	if active_trap == null or not is_instance_valid(active_trap):
		return
	var current_focus := get_viewport().gui_get_focus_owner()
	if current_focus == null or not active_trap.is_ancestor_of(current_focus):
		var target := find_first_focusable(active_trap)
		if target != null:
			target.grab_focus()

func _should_show_ring() -> bool:
	return focus_ring_enabled and (current_input_mode == InputMode.KEYBOARD or current_input_mode == InputMode.CONTROLLER)

func _update_ring_state() -> void:
	if _overlay != null and _overlay.has_method("set_target_control"):
		var show_target := current_focused_control if _should_show_ring() else null
		_overlay.call("set_target_control", show_target)
	focus_ring_visibility_changed.emit(_should_show_ring())
