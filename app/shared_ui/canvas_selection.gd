# CanvasSelection — Object selection manager with box marquee and overlap cycling
class_name CanvasSelection
extends Node

signal selection_changed(selected_ids: Array)

var _selected_ids: Array = []
var _last_click_pos := Vector2(-9999, -9999)
var _overlap_cycle_index := 0


func select_single(p_id: String) -> void:
	_selected_ids.clear()
	if not p_id.is_empty():
		_selected_ids.append(p_id)
	selection_changed.emit(_selected_ids.duplicate())


func toggle_select(p_id: String) -> void:
	if p_id.is_empty():
		return
	if p_id in _selected_ids:
		_selected_ids.erase(p_id)
	else:
		_selected_ids.append(p_id)
	selection_changed.emit(_selected_ids.duplicate())


func select_multiple(p_ids: Array) -> void:
	_selected_ids.clear()
	for id in p_ids:
		if not (id in _selected_ids):
			_selected_ids.append(id)
	selection_changed.emit(_selected_ids.duplicate())


func clear_selection() -> void:
	if not _selected_ids.is_empty():
		_selected_ids.clear()
		selection_changed.emit(_selected_ids.duplicate())


func get_selected_ids() -> Array:
	return _selected_ids.duplicate()


func is_selected(p_id: String) -> bool:
	return p_id in _selected_ids


func cycle_overlap_at(p_click_pos: Vector2, p_overlapping_ids: Array) -> String:
	if p_overlapping_ids.is_empty():
		clear_selection()
		return ""
	
	if p_click_pos.distance_to(_last_click_pos) < 5.0:
		_overlap_cycle_index = (_overlap_cycle_index + 1) % p_overlapping_ids.size()
	else:
		_overlap_cycle_index = 0
		_last_click_pos = p_click_pos
	
	var chosen_id: String = p_overlapping_ids[_overlap_cycle_index]
	select_single(chosen_id)
	return chosen_id
