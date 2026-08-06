# SelectionSets — State management for object locking, hiding, soloing, and named selection groups
class_name SelectionSets
extends Node

signal state_changed()

var _locked_ids: Dictionary = {}
var _hidden_ids: Dictionary = {}
var _solo_ids: Dictionary = {}
var _selection_sets: Dictionary = {} # set_name -> Array of IDs


func set_locked(p_id: String, p_locked: bool) -> void:
	if p_locked:
		_locked_ids[p_id] = true
	else:
		_locked_ids.erase(p_id)
	state_changed.emit()


func is_locked(p_id: String) -> bool:
	return _locked_ids.has(p_id)


func set_hidden(p_id: String, p_hidden: bool) -> void:
	if p_hidden:
		_hidden_ids[p_id] = true
	else:
		_hidden_ids.erase(p_id)
	state_changed.emit()


func is_hidden(p_id: String) -> bool:
	return _hidden_ids.has(p_id)


func set_solo(p_id: String, p_solo: bool) -> void:
	if p_solo:
		_solo_ids[p_id] = true
	else:
		_solo_ids.erase(p_id)
	state_changed.emit()


func is_solo_active() -> bool:
	return not _solo_ids.is_empty()


func is_visible(p_id: String) -> bool:
	if is_hidden(p_id):
		return false
	if is_solo_active():
		return _solo_ids.has(p_id)
	return true


func save_selection_set(p_name: String, p_ids: Array) -> void:
	if p_name.is_empty():
		return
	_selection_sets[p_name] = p_ids.duplicate()
	state_changed.emit()


func get_selection_set(p_name: String) -> Array:
	return _selection_sets.get(p_name, []).duplicate()


func delete_selection_set(p_name: String) -> bool:
	if _selection_sets.has(p_name):
		_selection_sets.erase(p_name)
		state_changed.emit()
		return true
	return false


func list_selection_sets() -> Array:
	return _selection_sets.keys()
