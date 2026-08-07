# DocumentSelection -- Shared editor selection for layers, bones, clips, tracks, and keys.
class_name DocumentSelection
extends Node

signal selection_changed(kind: String, item_id: String, context: Dictionary)

var _kind := ""
var _item_id := ""
var _context: Dictionary = {}


func select(kind: String, item_id: String, context: Dictionary = {}) -> bool:
	var next_kind := kind.strip_edges()
	var next_id := item_id.strip_edges()
	var next_context := context.duplicate(true)
	if _kind == next_kind and _item_id == next_id and _context == next_context:
		return false
	_kind = next_kind
	_item_id = next_id
	_context = next_context
	selection_changed.emit(_kind, _item_id, _context.duplicate(true))
	return true


func clear() -> void:
	select("", "", {})


func get_kind() -> String:
	return _kind


func get_item_id() -> String:
	return _item_id


func get_context() -> Dictionary:
	return _context.duplicate(true)


func is_selected(kind: String, item_id: String) -> bool:
	return _kind == kind and _item_id == item_id
