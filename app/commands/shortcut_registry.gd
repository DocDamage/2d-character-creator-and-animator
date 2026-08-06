# ShortcutRegistry — Central application command & shortcut registry
# Autoload: ShortcutRegistry
# Manages command definitions, shortcut bindings, searching, and key input dispatch
extends Node

signal command_registered(command_id: String)
signal command_unregistered(command_id: String)
signal shortcut_rebound(command_id: String, new_shortcut: String)
signal command_executed(command_id: String)

var _commands: Dictionary = {} # command_id -> Dictionary
var _custom_bindings: Dictionary = {} # command_id -> String shortcut override
var _enabled: bool = true

func register_command(command_id: String, title: String, category: String, default_shortcut: String, callback: Callable, keywords: Array = [], description: String = "") -> bool:
	if command_id.is_empty() or title.is_empty():
		return false

	var bound_shortcut := _custom_bindings.get(command_id, default_shortcut) as String
	var cmd := {
		"id": command_id,
		"title": title,
		"category": category,
		"description": description,
		"default_shortcut": default_shortcut,
		"shortcut": bound_shortcut,
		"callable": callback,
		"keywords": keywords,
		"enabled": true
	}
	_commands[command_id] = cmd
	command_registered.emit(command_id)
	return true


func unregister_command(command_id: String) -> bool:
	if not _commands.has(command_id):
		return false
	_commands.erase(command_id)
	command_unregistered.emit(command_id)
	return true


func has_command(command_id: String) -> bool:
	return _commands.has(command_id)


func get_command(command_id: String) -> Dictionary:
	return _commands.get(command_id, {}).duplicate()


func get_all_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cid in _commands.keys():
		result.append((_commands[cid] as Dictionary).duplicate())
	return result


func execute_command(command_id: String) -> bool:
	if not _commands.has(command_id):
		return false
	var cmd: Dictionary = _commands[command_id]
	if not cmd.get("enabled", true):
		return false
	var cb: Callable = cmd.get("callable", Callable())
	if cb.is_valid():
		cb.call()
		command_executed.emit(command_id)
		if DiagnosticsService != null:
			DiagnosticsService.info("Executed command: " + command_id, "ShortcutRegistry")
		return true
	return false


func search_commands(query: String) -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	var results: Array[Dictionary] = []
	for cid in _commands.keys():
		var cmd: Dictionary = _commands[cid]
		if q.is_empty():
			results.append(cmd.duplicate())
			continue
		var title: String = (cmd.get("title", "") as String).to_lower()
		var cat: String = (cmd.get("category", "") as String).to_lower()
		var desc: String = (cmd.get("description", "") as String).to_lower()
		var matches := title.contains(q) or cat.contains(q) or desc.contains(q)
		if not matches:
			var kw_list: Array = cmd.get("keywords", [])
			for kw in kw_list:
				if (kw as String).to_lower().contains(q):
					matches = true
					break
		if matches:
			results.append(cmd.duplicate())
	return results


func rebind_shortcut(command_id: String, new_shortcut: String) -> bool:
	if not _commands.has(command_id):
		return false
	_commands[command_id]["shortcut"] = new_shortcut
	_custom_bindings[command_id] = new_shortcut
	shortcut_rebound.emit(command_id, new_shortcut)
	return true


func reset_shortcut(command_id: String) -> bool:
	if not _commands.has(command_id):
		return false
	var def_sc: String = _commands[command_id].get("default_shortcut", "")
	_commands[command_id]["shortcut"] = def_sc
	_custom_bindings.erase(command_id)
	shortcut_rebound.emit(command_id, def_sc)
	return true


func reset_all_shortcuts() -> void:
	_custom_bindings.clear()
	for cid in _commands.keys():
		var def_sc: String = _commands[cid].get("default_shortcut", "")
		_commands[cid]["shortcut"] = def_sc
		shortcut_rebound.emit(cid, def_sc)


func find_command_by_shortcut(shortcut_str: String) -> Dictionary:
	if shortcut_str.is_empty():
		return {}
	var normalized := shortcut_str.to_upper()
	for cid in _commands.keys():
		var cmd: Dictionary = _commands[cid]
		var sc: String = cmd.get("shortcut", "")
		if sc.to_upper() == normalized:
			return cmd.duplicate()
	return {}


func export_bindings() -> Dictionary:
	return _custom_bindings.duplicate()


func import_bindings(data: Dictionary) -> bool:
	if data == null:
		return false
	_custom_bindings = data.duplicate()
	for cid in _commands.keys():
		if _custom_bindings.has(cid):
			_commands[cid]["shortcut"] = _custom_bindings[cid]
		else:
			_commands[cid]["shortcut"] = _commands[cid].get("default_shortcut", "")
	return true


func shortcut_to_string(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return ""
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return ""
	var parts: Array[String] = []
	if key_event.ctrl_pressed:
		parts.append("Ctrl")
	if key_event.alt_pressed:
		parts.append("Alt")
	if key_event.shift_pressed:
		parts.append("Shift")
	if key_event.meta_pressed:
		parts.append("Cmd")
	
	var key_name := OS.get_keycode_string(key_event.keycode)
	if key_name.is_empty():
		key_name = OS.get_keycode_string(key_event.physical_keycode)
	if key_name.is_empty() or key_name in ["Control", "Shift", "Alt", "Meta"]:
		return ""
	parts.append(key_name)
	return "+".join(parts)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var sc_str := shortcut_to_string(key_event)
	if sc_str.is_empty():
		return
	for cid in _commands.keys():
		var cmd: Dictionary = _commands[cid]
		var bound: String = cmd.get("shortcut", "")
		if not bound.is_empty() and bound.to_upper() == sc_str.to_upper():
			if execute_command(cid):
				get_viewport().set_input_as_handled()
				break
