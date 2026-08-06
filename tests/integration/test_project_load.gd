# Integration Test Suite — Project Load & Diagnostics (REQ-DOC-005)
extends Node

const ProjectSchema = preload("res://core/documents/project_schema.gd")

var _passed := 0
var _failed := 0
var _errors: Array[String] = []

var _completed_signal_count := 0
var _last_completed_path := ""
var _last_completed_version := ""
var _failed_signal_count := 0
var _last_failed_path := ""
var _last_failed_error := ""


func _ready() -> void:
	SerializationService.load_completed.connect(_on_load_completed)
	SerializationService.load_failed.connect(_on_load_failed)


func _on_load_completed(path: String, version: String) -> void:
	_completed_signal_count += 1
	_last_completed_path = path
	_last_completed_version = version


func _on_load_failed(path: String, error: String) -> void:
	_failed_signal_count += 1
	_last_failed_path = path
	_last_failed_error = error


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	if not SerializationService.load_completed.is_connected(_on_load_completed):
		SerializationService.load_completed.connect(_on_load_completed)
	if not SerializationService.load_failed.is_connected(_on_load_failed):
		SerializationService.load_failed.connect(_on_load_failed)

	print("[TEST 18] Project Load & Diagnostics Workflows (REQ-DOC-005)...")
	test_valid_project_load()
	test_non_existent_file_load()
	test_corrupt_json_load()
	test_schema_validation_failure_load()
	test_unknown_fields_preservation_and_diagnostics()
	test_last_load_diagnostics_query()

	print("  Project Load tests finished: %d PASS, %d FAIL" % [_passed, _failed])
	return {
		"passed": _passed,
		"failed": _failed,
		"errors": _errors
	}


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
		_passed += 1
	else:
		printerr("  FAIL: %s" % msg)
		_failed += 1
		_errors.append(msg)


func test_valid_project_load() -> void:
	var test_path := "user://test_load_valid.chrproj"
	var manifest := ProjectSchema.create_default_manifest("Valid Load Test Project")
	manifest["settings"]["pixel_mode"] = true

	var saved := SerializationService.save_project(manifest, test_path)
	assert_true(saved, "Saved project cleanly to " + test_path)

	_completed_signal_count = 0
	_last_completed_path = ""
	_last_completed_version = ""

	var loaded := SerializationService.load_project(test_path)

	assert_true(not loaded.is_empty(), "load_project returned non-empty dictionary")
	assert_true(loaded.get("project_name", "") == "Valid Load Test Project", "Loaded project_name matches")
	assert_true(loaded.get("settings", {}).get("pixel_mode", false) == true, "Loaded settings.pixel_mode matches")
	assert_true(_completed_signal_count > 0 and _last_completed_path == test_path, "load_completed signal emitted for valid project")
	assert_true(_last_completed_version == ProjectSchema.SCHEMA_VERSION, "load_completed schema_version matches")

	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)


func test_non_existent_file_load() -> void:
	var dummy_path := "user://non_existent_project_file_9999.chrproj"
	if FileAccess.file_exists(dummy_path):
		DirAccess.remove_absolute(dummy_path)

	_failed_signal_count = 0
	_last_failed_path = ""

	var loaded := SerializationService.load_project(dummy_path)
	var diag := SerializationService.load_project_with_diagnostics(dummy_path)

	assert_true(loaded.is_empty(), "load_project returned empty dict for non-existent file")
	assert_true(_failed_signal_count > 0 and _last_failed_path == dummy_path, "load_failed signal emitted for non-existent file")
	assert_true(diag.get("success", true) == false, "Diagnostics reported success=false")
	assert_true(diag.get("errors", []).size() > 0, "Diagnostics contains error message for missing file")


func test_corrupt_json_load() -> void:
	var corrupt_path := "user://test_corrupt_json.chrproj"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{ 'invalid_json': true, missing_quotes }")
	file.close()

	_failed_signal_count = 0
	_last_failed_path = ""

	var loaded := SerializationService.load_project(corrupt_path)
	var diag := SerializationService.load_project_with_diagnostics(corrupt_path)

	assert_true(loaded.is_empty(), "load_project returned empty dict for corrupt JSON")
	assert_true(_failed_signal_count > 0 and _last_failed_path == corrupt_path, "load_failed signal emitted for corrupt JSON")
	assert_true(diag.get("success", true) == false, "Diagnostics reported success=false for corrupt JSON")

	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(corrupt_path)


func test_schema_validation_failure_load() -> void:
	var invalid_schema_path := "user://test_invalid_schema.chrproj"
	var bad_manifest := ProjectSchema.create_default_manifest("Bad Schema Project")
	bad_manifest.erase("project_id")

	var file := FileAccess.open(invalid_schema_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad_manifest))
	file.close()

	var loaded := SerializationService.load_project(invalid_schema_path)
	var diag := SerializationService.load_project_with_diagnostics(invalid_schema_path)

	assert_true(loaded.is_empty(), "load_project returned empty dict for schema validation failure")
	assert_true(diag.get("success", true) == false, "Diagnostics reported success=false for schema validation error")
	assert_true(diag.get("errors", []).size() > 0, "Diagnostics captured schema validation errors")

	if FileAccess.file_exists(invalid_schema_path):
		DirAccess.remove_absolute(invalid_schema_path)


func test_unknown_fields_preservation_and_diagnostics() -> void:
	var unknown_path := "user://test_unknown_fields.chrproj"
	var manifest := ProjectSchema.create_default_manifest("Unknown Fields Project")
	manifest["custom_plugin_data"] = {"author_note": "custom_extension"}
	manifest["objects"]["unknown_category"] = {"custom_item": 42}

	var file := FileAccess.open(unknown_path, FileAccess.WRITE)
	file.store_string(SerializationService.serialize_deterministic(manifest))
	file.close()

	var loaded := SerializationService.load_project(unknown_path)
	var diag := SerializationService.load_project_with_diagnostics(unknown_path)

	assert_true(not loaded.is_empty(), "load_project loaded project with unknown fields successfully")
	assert_true(loaded.has("custom_plugin_data"), "Preserved unknown root field 'custom_plugin_data'")
	assert_true(loaded.get("custom_plugin_data", {}).get("author_note", "") == "custom_extension", "Preserved unknown root field contents")
	assert_true(loaded.get("objects", {}).has("unknown_category"), "Preserved unknown object category 'unknown_category'")
	assert_true(diag.get("success", false) == true, "Diagnostics reported success=true when unknown fields present")
	assert_true(diag.get("unknown_fields", []).has("custom_plugin_data"), "Diagnostics identified unknown root field")
	assert_true(diag.get("unknown_fields", []).has("unknown_category"), "Diagnostics identified unknown object category")
	assert_true(diag.get("warnings", []).size() >= 2, "Diagnostics generated warning entries for unknown fields")

	if FileAccess.file_exists(unknown_path):
		DirAccess.remove_absolute(unknown_path)


func test_last_load_diagnostics_query() -> void:
	var valid_path := "user://test_last_load_diag.chrproj"
	var manifest := ProjectSchema.create_default_manifest("Last Diag Project")
	SerializationService.save_project(manifest, valid_path)

	SerializationService.load_project(valid_path)
	var last_diag := SerializationService.get_last_load_diagnostics()

	assert_true(not last_diag.is_empty(), "get_last_load_diagnostics returned non-empty dictionary")
	assert_true(last_diag.get("success", false) == true, "Last load diagnostics indicates success")
	assert_true(last_diag.get("schema_version", "") == ProjectSchema.SCHEMA_VERSION, "Last load diagnostics schema_version matches")

	if FileAccess.file_exists(valid_path):
		DirAccess.remove_absolute(valid_path)
