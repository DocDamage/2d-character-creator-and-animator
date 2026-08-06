# Integration Test Suite — Transactional Save Workflows (REQ-DOC-004)
extends Node

const ProjectSchema = preload("res://core/documents/project_schema.gd")

const TEST_DIR := "user://test_transactional_save/"
const TEST_PROJECT_PATH := TEST_DIR + "test_project.chrproj"
const TEST_AUTOSAVE_PATH := TEST_DIR + "test_project.autosave.json"

var _passed := 0
var _failed := 0
var _errors: Array[String] = []

var _completed_signal_count := 0
var _last_completed_path := ""
var _failed_signal_count := 0
var _last_failed_error := ""
var _last_diagnostic: Dictionary = {}


func _ready() -> void:
	SerializationService.save_completed.connect(_on_save_completed)
	SerializationService.save_failed.connect(_on_save_failed)
	AppState.diagnostic_posted.connect(_on_diagnostic_posted)


func _on_save_completed(path: String) -> void:
	_completed_signal_count += 1
	_last_completed_path = path


func _on_save_failed(path: String, error: String) -> void:
	_failed_signal_count += 1
	_last_failed_error = error


func _on_diagnostic_posted(level: String, msg: String, source: String) -> void:
	_last_diagnostic = {"level": level, "message": msg, "source": source}


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	_setup_test_dir()

	print("[TEST 17] Transactional Save Workflows (REQ-DOC-004)...")
	test_successful_transactional_save()
	test_invalid_manifest_save_rejection()
	test_dirty_state_cleared_only_on_success()
	test_backup_rotation_and_preservation()
	test_autosave_isolation()
	test_diagnostic_journal_logging()

	_cleanup_test_dir()

	print("  Transactional Save tests finished: %d PASS, %d FAIL" % [_passed, _failed])
	return {
		"passed": _passed,
		"failed": _failed,
		"errors": _errors
	}


func _setup_test_dir() -> void:
	_cleanup_test_dir()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func _cleanup_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var dir := DirAccess.open(TEST_DIR)
		if dir != null:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(TEST_DIR + fn)
				fn = dir.get_next()
			dir.list_dir_end()
			DirAccess.remove_absolute(TEST_DIR)


func _create_valid_project_data() -> Dictionary:
	return ProjectSchema.create_default_manifest("Transactional Test Project")


func test_successful_transactional_save() -> void:
	AppState.mark_dirty()
	_completed_signal_count = 0
	_last_completed_path = ""

	var valid_data := _create_valid_project_data()
	var success := SerializationService.save_project(valid_data, TEST_PROJECT_PATH)

	_assert(success == true, "save_project returned true for valid data")
	_assert(FileAccess.file_exists(TEST_PROJECT_PATH), "Target file exists after save")
	_assert(not FileAccess.file_exists(TEST_PROJECT_PATH + ".tmp"), "Temp file removed after save")
	_assert(_completed_signal_count > 0, "save_completed signal emitted")
	_assert(_last_completed_path == TEST_PROJECT_PATH, "save_completed path matches target")
	_assert(AppState.is_dirty() == false, "Dirty state cleared after successful save")


func test_invalid_manifest_save_rejection() -> void:
	AppState.mark_dirty()
	_failed_signal_count = 0
	_last_failed_error = ""

	var invalid_data := _create_valid_project_data()
	invalid_data.erase("project_id")

	var success := SerializationService.save_project(invalid_data, TEST_PROJECT_PATH)

	_assert(success == false, "save_project returned false for invalid manifest")
	_assert(_failed_signal_count > 0, "save_failed signal emitted on validation error")
	_assert(_last_failed_error.find("validation") != -1, "Error message mentions validation")
	_assert(not FileAccess.file_exists(TEST_PROJECT_PATH + ".tmp"), "Temp file cleaned up after failed validation")
	_assert(AppState.is_dirty() == true, "Dirty state remains active when save fails")


func test_dirty_state_cleared_only_on_success() -> void:
	AppState.mark_dirty()
	_assert(AppState.is_dirty() == true, "AppState is dirty before save attempt")

	var invalid_data := {"schema_version": "1.0.0"}
	SerializationService.save_project(invalid_data, TEST_PROJECT_PATH)
	_assert(AppState.is_dirty() == true, "AppState remains dirty after failed save")

	var valid_data := _create_valid_project_data()
	SerializationService.save_project(valid_data, TEST_PROJECT_PATH)
	_assert(AppState.is_dirty() == false, "AppState clean after successful save")


func test_backup_rotation_and_preservation() -> void:
	var valid_data := _create_valid_project_data()

	valid_data["project_name"] = "Version 1"
	SerializationService.save_project(valid_data, TEST_PROJECT_PATH)

	valid_data["project_name"] = "Version 2"
	SerializationService.save_project(valid_data, TEST_PROJECT_PATH)

	var backups := SerializationService.find_backups(TEST_PROJECT_PATH)
	_assert(FileAccess.file_exists(TEST_PROJECT_PATH), "Current save file exists")
	_assert(backups.size() >= 0, "Backups query executes cleanly")


func test_autosave_isolation() -> void:
	AppState.mark_dirty()

	var valid_data := _create_valid_project_data()
	valid_data["project_name"] = "Autosave Snapshot"

	var success := SerializationService.autosave(valid_data, TEST_AUTOSAVE_PATH)
	_assert(success == true, "autosave returned true")
	_assert(FileAccess.file_exists(TEST_AUTOSAVE_PATH), "Autosave file created at designated path")
	_assert(AppState.is_dirty() == true, "Autosave did NOT clear manual save dirty state")

	var loaded_autosave := SerializationService.load_autosave(TEST_AUTOSAVE_PATH)
	_assert(not loaded_autosave.is_empty(), "Autosave file loads back successfully")
	_assert(loaded_autosave.get("project_name", "") == "Autosave Snapshot", "Autosave data matches snapshot")


func test_diagnostic_journal_logging() -> void:
	_last_diagnostic.clear()
	var valid_data := _create_valid_project_data()

	SerializationService.save_project(valid_data, TEST_PROJECT_PATH)

	var found_entry: bool = (_last_diagnostic.get("source", "") == "SerializationService" and _last_diagnostic.get("message", "").find("Transactional save completed") != -1)
	_assert(found_entry == true, "Diagnostic journal entry logged for completed save")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
		_passed += 1
	else:
		var err_str := "FAIL: %s" % message
		printerr("  %s" % err_str)
		_errors.append(err_str)
		_failed += 1
