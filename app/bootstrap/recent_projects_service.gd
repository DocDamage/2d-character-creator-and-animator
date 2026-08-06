# RecentProjectsService — Service for managing, persisting, and querying recent project entries
# Autoload: RecentProjectsService
extends Node

## === Signals ================================================================

signal recent_projects_changed

## === Constants ==============================================================

const SAVE_PATH := "user://recent_projects.json"
const MAX_RECENT_PROJECTS := 10

## === State ==================================================================

var _recent_projects: Array[Dictionary] = []

## === Lifecycle ==============================================================

func _ready() -> void:
	load_from_disk()


## === Public API =============================================================

func get_recent_projects() -> Array[Dictionary]:
	refresh_existence()
	return _recent_projects.duplicate(true)


func add_project(path: String, title: String = "") -> void:
	if path.strip_edges().is_empty():
		return

	var clean_path := path.simplify_path()
	var proj_title := title
	if proj_title.is_empty():
		proj_title = clean_path.get_file().get_basename()
		if proj_title.is_empty():
			proj_title = clean_path

	# Remove existing entry if present
	for i in range(_recent_projects.size() - 1, -1, -1):
		if _recent_projects[i].get("path", "") == clean_path:
			_recent_projects.remove_at(i)

	var entry: Dictionary = {
		"path": clean_path,
		"title": proj_title,
		"last_modified": Time.get_datetime_string_from_system(false, true),
		"exists": check_path_exists(clean_path)
	}

	_recent_projects.push_front(entry)

	if _recent_projects.size() > MAX_RECENT_PROJECTS:
		_recent_projects.resize(MAX_RECENT_PROJECTS)

	save_to_disk()
	recent_projects_changed.emit()


func remove_project(path: String) -> void:
	var clean_path := path.simplify_path()
	var removed := false
	for i in range(_recent_projects.size() - 1, -1, -1):
		if _recent_projects[i].get("path", "") == clean_path:
			_recent_projects.remove_at(i)
			removed = true

	if removed:
		save_to_disk()
		recent_projects_changed.emit()


func clear_all() -> void:
	_recent_projects.clear()
	save_to_disk()
	recent_projects_changed.emit()


func clear_missing() -> void:
	var changed := false
	for i in range(_recent_projects.size() - 1, -1, -1):
		var p: String = _recent_projects[i].get("path", "")
		if not check_path_exists(p):
			_recent_projects.remove_at(i)
			changed = true

	if changed:
		save_to_disk()
		recent_projects_changed.emit()


func refresh_existence() -> void:
	var changed := false
	for i in range(_recent_projects.size()):
		var p: String = _recent_projects[i].get("path", "")
		var current_exists := check_path_exists(p)
		if _recent_projects[i].get("exists", false) != current_exists:
			_recent_projects[i]["exists"] = current_exists
			changed = true
	if changed:
		save_to_disk()


func check_path_exists(path: String) -> bool:
	if path.is_empty():
		return false
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		var json_text := JSON.stringify(_recent_projects, "\t")
		file.store_string(json_text)
		file.close()


func load_from_disk() -> void:
	_recent_projects.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file != null:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(content) == OK and json.data is Array:
			for item in json.data:
				if item is Dictionary and item.has("path"):
					var p: String = item["path"]
					item["exists"] = check_path_exists(p)
					_recent_projects.append(item)


func export_settings() -> Dictionary:
	return {
		"recent_projects": _recent_projects.duplicate(true)
	}


func import_settings(data: Dictionary) -> bool:
	if data == null or not data.has("recent_projects"):
		return false
	var arr = data["recent_projects"]
	if arr is Array:
		_recent_projects.clear()
		for item in arr:
			if item is Dictionary and item.has("path"):
				item["exists"] = check_path_exists(item["path"])
				_recent_projects.append(item)
		save_to_disk()
		recent_projects_changed.emit()
		return true
	return false
