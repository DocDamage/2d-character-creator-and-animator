# CommandHistory — Command pattern implementation and undo/redo stack manager
class_name CommandHistory
extends Node

signal history_changed()
signal command_executed(command_name: String)
signal command_undone(command_name: String)

class Command extends RefCounted:
	func execute() -> void:
		pass
	func undo() -> void:
		pass
	func get_name() -> String:
		return "Base Command"

class MacroCommand extends Command:
	var _name: String
	var _commands: Array = []
	
	func _init(p_name: String = "Macro Action") -> void:
		_name = p_name
	
	func add_command(cmd: Command) -> void:
		_commands.append(cmd)
	
	func execute() -> void:
		for cmd in _commands:
			cmd.execute()
	
	func undo() -> void:
		for i in range(_commands.size() - 1, -1, -1):
			_commands[i].undo()
	
	func get_name() -> String:
		return _name

const MAX_HISTORY_STEPS := 100

var _undo_stack: Array = []
var _redo_stack: Array = []
var _active_macro: MacroCommand = null


func push_and_execute(p_command: Command) -> bool:
	if p_command == null:
		return false
	
	if _active_macro != null:
		p_command.execute()
		_active_macro.add_command(p_command)
		return true
	
	p_command.execute()
	_undo_stack.append(p_command)
	if _undo_stack.size() > MAX_HISTORY_STEPS:
		_undo_stack.pop_front()
	
	_redo_stack.clear()
	command_executed.emit(p_command.get_name())
	history_changed.emit()
	return true


func undo() -> bool:
	if not can_undo():
		return false
	
	var cmd: Command = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	command_undone.emit(cmd.get_name())
	history_changed.emit()
	return true


func redo() -> bool:
	if not can_redo():
		return false
	
	var cmd: Command = _redo_stack.pop_back()
	cmd.execute()
	_undo_stack.append(cmd)
	command_executed.emit(cmd.get_name())
	history_changed.emit()
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty() and _active_macro == null


func can_redo() -> bool:
	return not _redo_stack.is_empty() and _active_macro == null


func begin_macro(p_name: String) -> void:
	if _active_macro == null:
		_active_macro = MacroCommand.new(p_name)


func end_macro() -> void:
	if _active_macro != null:
		var macro := _active_macro
		_active_macro = null
		if not macro._commands.is_empty():
			_undo_stack.append(macro)
			_redo_stack.clear()
			command_executed.emit(macro.get_name())
			history_changed.emit()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_active_macro = null
	history_changed.emit()


func get_undo_stack_names() -> Array:
	var names: Array = []
	for cmd in _undo_stack:
		names.append(cmd.get_name())
	return names


func get_redo_stack_names() -> Array:
	var names: Array = []
	for cmd in _redo_stack:
		names.append(cmd.get_name())
	return names
