# LpcNameSequence -- Durable, monotonic display-name numbering for LPC projects.
class_name LpcNameSequence
extends RefCounted

const STATE_PATH := "user://lpc_creator_state.json"


static func reserve_next(state_path: String = STATE_PATH) -> int:
	var state := load_state(state_path)
	var index := maxi(1, int(state.get("next_display_name_index", 1)))
	state["next_display_name_index"] = index + 1
	save_state(state, state_path)
	return index


static func load_state(state_path: String = STATE_PATH) -> Dictionary:
	if not FileAccess.file_exists(state_path): return {"next_display_name_index": 1}
	var file := FileAccess.open(state_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	if file != null: file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {"next_display_name_index": 1}


static func save_state(state: Dictionary, state_path: String = STATE_PATH) -> bool:
	var directory := state_path.get_base_dir()
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(_absolute(directory))
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return true


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
