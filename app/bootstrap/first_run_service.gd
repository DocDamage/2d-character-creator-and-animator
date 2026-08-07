# FirstRunService -- Persists the small amount of state needed for a clean first-run experience.
extends Node

const SETTINGS_PATH := "user://first_run.json"

var _completed := false


func _ready() -> void:
	_load()


func is_first_run() -> bool:
	return not _completed


func complete_onboarding() -> void:
	if _completed: return
	_completed = true
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"completed": true, "completed_at": Time.get_unix_time_from_system()}))
		file.close()


func reset_for_testing() -> void:
	_completed = false
	if FileAccess.file_exists(SETTINGS_PATH): DirAccess.remove_absolute(SETTINGS_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null: return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary: _completed = bool((data as Dictionary).get("completed", false))
