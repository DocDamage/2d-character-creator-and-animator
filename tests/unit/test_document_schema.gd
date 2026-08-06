# TestDocumentSchema — Unit tests for ProjectSchema manifest creation and validation
extends Node

const ProjectSchema = preload("res://core/documents/project_schema.gd")

var _pass_count := 0
var _fail_count := 0
var _errors: Array[String] = []

func run_all_tests() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	_errors.clear()

	print("[TEST 14] Project Manifest Schema Workflows (REQ-DOC-001)...")

	test_default_manifest_creation()
	test_default_manifest_validation()
	test_baseline_fixture_validation()
	test_missing_root_fields()
	test_invalid_field_types()
	test_missing_object_categories()
	test_invalid_settings()
	test_serialization_service_integration()

	print("  ProjectSchema tests finished: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	return {
		"passed": _pass_count,
		"failed": _fail_count,
		"errors": _errors
	}


func test_default_manifest_creation() -> void:
	var manifest := ProjectSchema.create_default_manifest("Test Project", "test-id-12345")
	_assert(manifest.get("schema_version") == ProjectSchema.SCHEMA_VERSION, "Default manifest contains correct schema_version")
	_assert(manifest.get("project_name") == "Test Project", "Default manifest contains project_name")
	_assert(manifest.get("project_id") == "test-id-12345", "Default manifest contains project_id")
	_assert(typeof(manifest.get("created_at")) in [TYPE_INT, TYPE_FLOAT], "created_at is timestamp")
	_assert(typeof(manifest.get("modified_at")) in [TYPE_INT, TYPE_FLOAT], "modified_at is timestamp")
	_assert(typeof(manifest.get("objects")) == TYPE_DICTIONARY, "objects is dictionary")
	_assert(typeof(manifest.get("settings")) == TYPE_DICTIONARY, "settings is dictionary")
	_assert(typeof(manifest.get("metadata")) == TYPE_DICTIONARY, "metadata is dictionary")


func test_default_manifest_validation() -> void:
	var manifest := ProjectSchema.create_default_manifest("Valid Project")
	var errors := ProjectSchema.validate_manifest(manifest)
	_assert(errors.is_empty(), "Default manifest produces 0 validation errors")
	_assert(ProjectSchema.is_valid(manifest) == true, "ProjectSchema.is_valid returns true for default manifest")


func test_baseline_fixture_validation() -> void:
	var data := SerializationService.load_project("res://tests/fixtures/baseline/valid_project.chrproj")
	_assert(not data.is_empty(), "Baseline fixture loaded non-empty")
	var errors := ProjectSchema.validate_manifest(data)
	_assert(errors.is_empty(), "Baseline fixture validates cleanly against ProjectSchema")


func test_missing_root_fields() -> void:
	var manifest := ProjectSchema.create_default_manifest("Test Project")
	manifest.erase("project_id")
	var errors := ProjectSchema.validate_manifest(manifest)
	_assert(not errors.is_empty(), "Erasing project_id triggers validation error")
	_assert("Missing root field: 'project_id'" in errors, "Correct missing field error string generated")


func test_invalid_field_types() -> void:
	var manifest := ProjectSchema.create_default_manifest("Test Project")
	manifest["project_name"] = 12345
	var errors := ProjectSchema.validate_manifest(manifest)
	_assert(not errors.is_empty(), "Invalid project_name type triggers error")


func test_missing_object_categories() -> void:
	var manifest := ProjectSchema.create_default_manifest("Test Project")
	var objs: Dictionary = manifest["objects"]
	objs.erase("characters")
	var errors := ProjectSchema.validate_manifest(manifest)
	_assert(not errors.is_empty(), "Missing object category 'characters' triggers error")


func test_invalid_settings() -> void:
	var manifest := ProjectSchema.create_default_manifest("Test Project")
	manifest["settings"]["default_fps"] = -5
	var errors := ProjectSchema.validate_manifest(manifest)
	_assert(not errors.is_empty(), "Negative default_fps triggers error")


func test_serialization_service_integration() -> void:
	var manifest := ProjectSchema.create_default_manifest("Integrated Project")
	var errors := SerializationService.validate_project(manifest)
	_assert(errors.is_empty(), "SerializationService.validate_project succeeds for valid manifest")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
		_pass_count += 1
	else:
		printerr("  FAIL: " + message)
		_fail_count += 1
		_errors.append(message)
