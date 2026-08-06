# SerializationService — Deterministic serialization, transactional save, and load with diagnostics
# Autoload: SerializationService
extends Node

const SCHEMA_VERSION := "1.0.0"
const TEMP_EXTENSION := ".tmp"
const BACKUP_EXTENSION := ".bak"
const MAX_BACKUPS := 10

const ProjectSchema = preload("res://core/documents/project_schema.gd")

signal save_completed(path: String)
signal save_failed(path: String, error: String)
signal load_completed(path: String, schema_version: String)
signal load_failed(path: String, error: String)
signal migration_applied(from_version: String, to_version: String)

var _last_load_diagnostics: Dictionary = {}

## === Public API — Save ======================================================

func save_project(project_data: Dictionary, path: String) -> bool:
	if path.is_empty():
		save_failed.emit(path, "Empty save path")
		return false
	var temp_path := path + TEMP_EXTENSION
	var backup_path := path + BACKUP_EXTENSION
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		save_failed.emit(path, "Cannot create directory: " + dir)
		return false

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(path, "Cannot write temp file: " + temp_path)
		return false
	file.store_string(_serialize(project_data))
	file.flush()
	file.close()

	if not _validate_file(temp_path):
		DirAccess.remove_absolute(temp_path)
		AppState.post_diagnostic("error", "Transactional save failed validation for " + temp_path, "SerializationService")
		save_failed.emit(path, "Written file failed validation")
		return false

	_rotate_backups(path)
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, backup_path) != OK and not _handle_copy_failure(path, backup_path):
			DirAccess.remove_absolute(temp_path)
			save_failed.emit(path, "Cannot create backup")
			return false

	if DirAccess.rename_absolute(temp_path, path) != OK:
		if DirAccess.copy_absolute(temp_path, path) == OK:
			DirAccess.remove_absolute(temp_path)
		else:
			if FileAccess.file_exists(backup_path):
				DirAccess.rename_absolute(backup_path, path)
			save_failed.emit(path, "Cannot finalize save")
			return false

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	AppState.post_diagnostic("info", "Transactional save completed for " + path, "SerializationService")
	save_completed.emit(path)
	AppState.clear_dirty()
	return true


func autosave(project_data: Dictionary, autosave_path: String) -> bool:
	if autosave_path.is_empty():
		return false
	var dir := autosave_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(autosave_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_serialize(project_data))
	file.close()
	return true


## === Public API — Load (REQ-DOC-005) =========================================

func get_last_load_diagnostics() -> Dictionary:
	return _last_load_diagnostics.duplicate(true)


func load_project(path: String) -> Dictionary:
	var res := load_project_with_diagnostics(path)
	return res.get("data", {}) if res.get("success", false) else {}


func load_project_with_diagnostics(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail_load(path, "File not found: " + path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail_load(path, "Cannot read file: " + path)
	var raw := file.get_as_text()
	file.close()

	if raw.strip_edges().is_empty():
		return _fail_load(path, "Empty project file: " + path)

	var data := _deserialize(raw)
	if data.is_empty():
		return _fail_load(path, "Deserialization produced empty data: " + path)

	var val_errors := ProjectSchema.validate_manifest(data)
	if not val_errors.is_empty():
		var result := _empty_load_result()
		for val_err in val_errors:
			result["errors"].append(val_err)
			AppState.post_diagnostic("error", "Validation error: " + val_err, "SerializationService")
		load_failed.emit(path, "Manifest validation failed for " + path)
		_last_load_diagnostics = result
		return result

	var version: String = data.get("schema_version", "0.0.0")
	if version != SCHEMA_VERSION:
		data = _migrate(data, version, SCHEMA_VERSION)
		if data.is_empty():
			return _fail_load(path, "Migration failed from " + version)

	var result := _empty_load_result()
	var unknown := ProjectSchema.get_unknown_fields(data)
	for r_field in unknown.get("unknown_root", []):
		var msg := "Preserved unknown root field: '%s'" % r_field
		result["unknown_fields"].append(r_field)
		result["warnings"].append(msg)
		AppState.post_diagnostic("warning", msg, "SerializationService")
	for c_field in unknown.get("unknown_categories", []):
		var msg := "Preserved unknown object category: '%s'" % c_field
		result["unknown_fields"].append(c_field)
		result["warnings"].append(msg)
		AppState.post_diagnostic("warning", msg, "SerializationService")

	result["success"] = true
	result["data"] = data
	result["schema_version"] = version
	_last_load_diagnostics = result

	AppState.post_diagnostic("info", "Project loaded successfully from " + path, "SerializationService")
	load_completed.emit(path, version)
	return result


func load_autosave(autosave_path: String) -> Dictionary:
	return load_project(autosave_path) if FileAccess.file_exists(autosave_path) else {}


## === Public API — Recovery & Utility ========================================

func find_backups(project_path: String) -> Array[String]:
	var results: Array[String] = []
	var base := project_path.trim_suffix(".json").trim_suffix(".chrproj").get_file()
	var dir := project_path.get_base_dir()
	var da := DirAccess.open(dir)
	if da != null:
		da.list_dir_begin()
		var fn := da.get_next()
		while fn != "":
			if fn.begins_with(base) and fn.ends_with(BACKUP_EXTENSION):
				results.append(dir.path_join(fn))
			fn = da.get_next()
		da.list_dir_end()
	results.sort()
	results.reverse()
	return results


func validate_project(data: Dictionary) -> PackedStringArray:
	return ProjectSchema.validate_manifest(data)


func clone_project(data: Dictionary) -> Dictionary:
	var cloned := data.duplicate(true)
	cloned["project_id"] = IDService.generate_uuid_v4()
	cloned["cloned_from"] = data.get("project_id", "")
	cloned["created_at"] = Time.get_unix_time_from_system()
	return cloned


## === Public API — Deterministic Serialization (REQ-DOC-003) ==================

func serialize_deterministic(data: Variant, include_metadata: bool = false) -> String:
	@warning_ignore("inferred_declaration")
	var working_copy = data
	if typeof(data) == TYPE_DICTIONARY:
		var copy := (data as Dictionary).duplicate(true)
		if include_metadata:
			copy["_serializer_version"] = SCHEMA_VERSION
		working_copy = copy
	return JSON.stringify(canonicalize(working_copy), "\t", true, false).replace("\r\n", "\n")


func canonicalize(data: Variant) -> Variant:
	match typeof(data):
		TYPE_DICTIONARY:
			var dict: Dictionary = data
			var keys := dict.keys()
			keys.sort()
			var res := {}
			for k in keys:
				res[k] = canonicalize(dict[k])
			return res
		TYPE_ARRAY:
			var res := []
			for elem in (data as Array):
				res.append(canonicalize(elem))
			return res
		TYPE_FLOAT:
			var val: float = data
			if val != val or val == INF or val == -INF:
				return 0
			var snapped := snappable_float(val)
			return int(snapped) if (snapped == floor(snapped) and abs(snapped) <= 9007199254740992.0) else snapped
		_:
			return data


func snappable_float(val: float) -> float:
	var rounded: float = round(val * 1000000.0) / 1000000.0
	return rounded if abs(val - rounded) < 0.0000001 else val


func compute_hash(data: Variant) -> String:
	return serialize_deterministic(data, true).sha256_text()


## === Internal Helpers =======================================================

func _serialize(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy["_serializer_version"] = SCHEMA_VERSION
	return serialize_deterministic(copy, false)


func _deserialize(raw: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(raw) != OK:
		AppState.post_diagnostic("error", "JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message(), "SerializationService")
		return {}
	var data = json.get_data()
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _validate_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data := _deserialize(file.get_as_text())
	file.close()
	return not data.is_empty() and ProjectSchema.is_valid(data)


func _rotate_backups(path: String) -> void:
	var backups := find_backups(path)
	while backups.size() >= MAX_BACKUPS:
		DirAccess.remove_absolute(backups.pop_back())


func _handle_copy_failure(src: String, _dst: String) -> bool:
	AppState.post_diagnostic("warning", "Backup copy failed for " + src, "SerializationService")
	return false


func _migrate(data: Dictionary, from_version: String, to_version: String) -> Dictionary:
	migration_applied.emit(from_version, to_version)
	return data


func _empty_load_result() -> Dictionary:
	return {
		"success": false,
		"data": {},
		"errors": PackedStringArray(),
		"warnings": PackedStringArray(),
		"unknown_fields": PackedStringArray(),
		"schema_version": ""
	}


func _fail_load(path: String, err: String) -> Dictionary:
	var res := _empty_load_result()
	res["errors"].append(err)
	AppState.post_diagnostic("error", err, "SerializationService")
	load_failed.emit(path, err)
	_last_load_diagnostics = res
	return res
