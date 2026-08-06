# CommandService — Central undo/redo command system
# Autoload: CommandService
# Every data-changing action must go through this service to support undo/redo.
extends Node

## === Signals ================================================================

signal undo_stack_changed(can_undo: bool, can_redo: bool)
signal command_executed(command_id: String, description: String)

## === Constants ==============================================================

const MAX_UNDO := 256

## === State ==================================================================

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _macro_recording: bool = false
var _macro_commands: Array[Dictionary] = []
var _macro_description: String = ""
var _enabled: bool = true

## === Public API =============================================================

func execute(do_data: Dictionary, undo_data: Dictionary, description: String = "") -> bool:
	if not _enabled:
		return false
	if _macro_recording:
		_macro_commands.append({"do": do_data, "undo": undo_data, "desc": description})
		return true
	return _push_and_apply(do_data, undo_data, description)


func can_undo() -> bool:
	return _undo_stack.size() > 0


func can_redo() -> bool:
	return _redo_stack.size() > 0


func undo() -> bool:
	if not can_undo():
		return false
	var cmd: Dictionary = _undo_stack.pop_back()
	_apply_command(cmd["undo"])
	_redo_stack.append(cmd)
	_notify_change()
	AppState.mark_dirty()
	return true


func redo() -> bool:
	if not can_redo():
		return false
	var cmd: Dictionary = _redo_stack.pop_back()
	_apply_command(cmd["do"])
	_undo_stack.append(cmd)
	_notify_change()
	AppState.mark_dirty()
	return true


func begin_macro(description: String = "") -> void:
	_macro_recording = true
	_macro_commands.clear()
	_macro_description = description


func end_macro() -> void:
	_macro_recording = false
	if _macro_commands.is_empty():
		return
	var macro_do := _macro_commands.duplicate()
	var macro_undo: Array[Dictionary] = []
	for i in range(_macro_commands.size() - 1, -1, -1):
		macro_undo.append(_macro_commands[i])
	_macro_commands.clear()
	_push_and_apply({"macro": macro_do}, {"macro": macro_undo}, _macro_description)


func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_notify_change()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func get_undo_count() -> int:
	return _undo_stack.size()


func get_redo_count() -> int:
	return _redo_stack.size()


func get_undo_description(index: int = -1) -> String:
	if _undo_stack.is_empty():
		return ""
	if index < 0:
		index = _undo_stack.size() + index
	if index < 0 or index >= _undo_stack.size():
		return ""
	return _undo_stack[index].get("desc", "")


func get_redo_description(index: int = 0) -> String:
	if _redo_stack.is_empty():
		return ""
	if index < 0 or index >= _redo_stack.size():
		return ""
	return _redo_stack[index].get("desc", "")


## === Internal ===============================================================

func _push_and_apply(do_data: Dictionary, undo_data: Dictionary, description: String) -> bool:
	var cmd := {
		"do": do_data,
		"undo": undo_data,
		"desc": description,
		"time": Time.get_unix_time_from_system(),
	}
	_apply_command(do_data)
	_undo_stack.append(cmd)
	_redo_stack.clear()
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_notify_change()
	AppState.mark_dirty()
	command_executed.emit(description, description)
	return true


func _apply_command(data: Dictionary) -> void:
	if data.has("macro"):
		var commands: Array = data["macro"]
		for cmd in commands:
			_apply_single(cmd["do"] if data["macro"].size() > 0 and commands[0].has("do") else cmd["undo"])
	else:
		_apply_single(data)


func _apply_single(data: Dictionary) -> void:
	var target: Node = null
	if data.has("target_path"):
		target = get_node_or_null(data["target_path"])
	elif data.has("target"):
		target = data["target"]
	else:
		return
	if not target:
		return
	var method: String = data.get("method", "")
	var args: Array = data.get("args", [])
	if method.is_empty() or not target.has_method(method):
		return
	if args.size() > 0:
		target.callv(method, args)
	else:
		target.call(method)


func _notify_change() -> void:
	undo_stack_changed.emit(can_undo(), can_redo())
	AppState.set_undo_available(can_undo())
	AppState.set_redo_available(can_redo())