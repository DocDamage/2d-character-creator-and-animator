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

func get_recent_projects(include_archived: bool = false) -> Array[Dictionary]:
	refresh_existence()
	var result: Array[Dictionary] = []
	for project in _recent_projects:
		if include_archived or not bool(project.get("archived", false)):
			result.append((project as Dictionary).duplicate(true))
	return result


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
		"exists": check_path_exists(clean_path),
		"archived": false,
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


func rename_project(path: String, title: String) -> Dictionary:
	var clean_title := title.strip_edges()
	if clean_title.is_empty(): return _failure("Project name cannot be empty.")
	var clean_path := path.simplify_path()
	if clean_path.begins_with("res://"): return _failure("Bundled samples are read-only. Save a copy before renaming it.")
	if not FileAccess.file_exists(clean_path): return _failure("Project file is missing. Locate it before renaming.")
	var manifest: Dictionary = SerializationService.load_project(clean_path)
	if manifest.is_empty(): return _failure("Project could not be read. Open Recovery & Quality to restore it.")
	manifest["project_name"] = clean_title
	manifest["modified_at"] = Time.get_unix_time_from_system()
	if not SerializationService.save_project(manifest, clean_path): return _failure("Project title could not be saved.")
	_update_entry(clean_path, {"title": clean_title, "last_modified": Time.get_datetime_string_from_system(false, true), "exists": true})
	return {"success": true, "path": clean_path, "title": clean_title}


func duplicate_project(path: String, title: String = "") -> Dictionary:
	var clean_path := path.simplify_path()
	if not FileAccess.file_exists(clean_path): return _failure("Project file is missing. Locate it before duplicating.")
	var manifest: Dictionary = SerializationService.load_project(clean_path)
	if manifest.is_empty(): return _failure("Project could not be read. Open Recovery & Quality to restore it.")
	var duplicate_title := title.strip_edges()
	if duplicate_title.is_empty(): duplicate_title = str(manifest.get("project_name", clean_path.get_file().get_basename())) + " Copy"
	# `get_basename()` preserves the directory. Take the file name first so a
	# `user://` or Windows-drive prefix never becomes part of the duplicate path.
	var base := clean_path.get_file().get_basename() + " Copy"
	var target := clean_path.get_base_dir().path_join(base + ".chrproj")
	var suffix := 2
	while FileAccess.file_exists(target):
		target = clean_path.get_base_dir().path_join(base + " " + str(suffix) + ".chrproj")
		suffix += 1
	var duplicate_manifest := manifest.duplicate(true)
	duplicate_manifest["cloned_from"] = str(manifest.get("project_id", ""))
	duplicate_manifest["project_id"] = IDService.generate_uuid_v4() if IDService != null else str(Time.get_unix_time_from_system())
	duplicate_manifest["project_name"] = duplicate_title
	duplicate_manifest["created_at"] = Time.get_unix_time_from_system()
	duplicate_manifest["modified_at"] = Time.get_unix_time_from_system()
	var asset_copy := _copy_project_assets(duplicate_manifest, target)
	if not asset_copy.get("success", false): return asset_copy
	if not SerializationService.save_project(duplicate_manifest, target): return _failure("Project copy could not be written.")
	add_project(target, duplicate_title)
	return {"success": true, "path": target, "title": duplicate_title, "assets_copied": int(asset_copy.get("assets_copied", 0))}


func archive_project(path: String, archived: bool = true) -> bool:
	var clean_path := path.simplify_path()
	for entry in _recent_projects:
		if str((entry as Dictionary).get("path", "")) == clean_path:
			entry["archived"] = archived
			entry["archived_at"] = Time.get_datetime_string_from_system(false, true) if archived else ""
			save_to_disk()
			recent_projects_changed.emit()
			return true
	return false


func reveal_project(path: String) -> Dictionary:
	var clean_path := path.simplify_path()
	if not check_path_exists(clean_path): return _failure("Project is missing. Locate it before revealing it.")
	var folder := ProjectSettings.globalize_path(clean_path.get_base_dir())
	var error := OS.shell_open(folder)
	return {"success": error == OK, "path": clean_path, "error": error}


func locate_project(old_path: String, new_path: String) -> bool:
	var old_clean := old_path.simplify_path()
	var next_clean := new_path.simplify_path()
	if not FileAccess.file_exists(next_clean): return false
	for entry in _recent_projects:
		if str((entry as Dictionary).get("path", "")) == old_clean:
			entry["path"] = next_clean
			entry["title"] = next_clean.get_file().get_basename()
			entry["exists"] = true
			entry["last_modified"] = Time.get_datetime_string_from_system(false, true)
			save_to_disk()
			recent_projects_changed.emit()
			return true
	return false


func get_actionable_error(path: String) -> Dictionary:
	var clean_path := path.simplify_path()
	if not check_path_exists(clean_path):
		return {"kind": "missing", "message": "This project moved or was deleted.", "actions": ["Locate project", "Remove from recents"]}
	if clean_path.begins_with("res://"):
		return {"kind": "read_only", "message": "Bundled samples cannot be edited in place.", "actions": ["Open sample", "Save As copy"]}
	var manifest: Dictionary = SerializationService.load_project(clean_path)
	if manifest.is_empty():
		return {"kind": "recovery", "message": "The project cannot be opened normally.", "actions": ["Open Recovery & Quality", "Remove from recents"]}
	return {"kind": "", "message": "", "actions": []}


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
					if not item.has("archived"): item["archived"] = false
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


func _update_entry(path: String, updates: Dictionary) -> void:
	for entry in _recent_projects:
		if str((entry as Dictionary).get("path", "")) == path:
			for key in updates: entry[key] = updates[key]
			save_to_disk()
			recent_projects_changed.emit()
			return


func _copy_project_assets(manifest: Dictionary, target_path: String) -> Dictionary:
	var objects: Dictionary = manifest.get("objects", {})
	var assets: Dictionary = objects.get("assets", {})
	if assets.is_empty():
		return {"success": true, "assets_copied": 0}
	var folder_name := target_path.get_file().get_basename() + "_assets"
	var asset_dir := target_path.get_base_dir().path_join(folder_name)
	var absolute_dir := _absolute_path(asset_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return _failure("Project copy could not create its artwork folder.")
	var copied := 0
	for asset_id in assets:
		var asset: Dictionary = (assets[asset_id] as Dictionary).duplicate(true)
		var source := str(asset.get("path", ""))
		if source.is_empty() or not FileAccess.file_exists(_absolute_path(source)):
			return _failure("Artwork is missing: " + (source if not source.is_empty() else str(asset_id)) + ". Repair it before duplicating the project.")
		var extension := source.get_extension()
		var name := str(asset_id) + ("." + extension if not extension.is_empty() else "")
		var destination := asset_dir.path_join(name)
		if DirAccess.copy_absolute(_absolute_path(source), _absolute_path(destination)) != OK:
			return _failure("Could not copy artwork for project duplicate: " + source)
		asset["path"] = destination
		assets[asset_id] = asset
		copied += 1
	objects["assets"] = assets
	manifest["objects"] = objects
	return {"success": true, "assets_copied": copied}


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message]}
