# Integration Test Suite — Schema Migrations (REQ-DOC-008)
extends Node

const SchemaMigration = preload("res://core/migrations/schema_migration.gd")
const ProjectSchema = preload("res://core/documents/project_schema.gd")

var _passed := 0
var _failed := 0
var _errors: Array[String] = []


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	print("[TEST 21] Schema Migrations Workflows (REQ-DOC-008)...")
	test_same_version_migration()
	test_0_1_0_to_1_0_0_migration()
	test_0_9_0_to_1_0_0_migration()
	test_custom_fields_preserved_during_migration()

	return {"passed": _passed, "failed": _failed, "errors": _errors}


func test_same_version_migration() -> void:
	var original := {"schema_version": "1.0.0", "project_name": "Test"}
	var migrated := SchemaMigration.migrate(original, "1.0.0", "1.0.0")
	_assert(migrated["schema_version"] == "1.0.0", "Same version migration returns version 1.0.0")


func test_0_1_0_to_1_0_0_migration() -> void:
	var old_manifest := {
		"schema_version": "0.1.0",
		"project_id": "prj_old123",
		"project_name": "Old Project",
		"created_at": 1000,
		"modified_at": 1000
	}
	var migrated := SchemaMigration.migrate(old_manifest, "0.1.0", "1.0.0")
	_assert(migrated["schema_version"] == "1.0.0", "Schema version upgraded to 1.0.0")
	_assert(migrated.has("objects"), "Migrated manifest has objects dictionary")
	_assert(migrated.has("settings"), "Migrated manifest has settings dictionary")
	_assert(ProjectSchema.is_valid(migrated), "Migrated 0.1.0 manifest passes ProjectSchema validation")


func test_0_9_0_to_1_0_0_migration() -> void:
	var old_manifest := {
		"schema_version": "0.9.0",
		"project_id": "prj_090",
		"project_name": "Mid Project",
		"created_at": 2000,
		"modified_at": 2000,
		"objects": {
			"characters": [], "rigs": [], "animations": [], "palettes": [], "weapons": []
		}
	}
	var migrated := SchemaMigration.migrate(old_manifest, "0.9.0", "1.0.0")
	_assert(migrated["schema_version"] == "1.0.0", "Schema version upgraded to 1.0.0 from 0.9.0")
	_assert(ProjectSchema.is_valid(migrated), "Migrated 0.9.0 manifest passes ProjectSchema validation")


func test_custom_fields_preserved_during_migration() -> void:
	var old_manifest := {
		"schema_version": "0.1.0",
		"project_id": "prj_custom",
		"project_name": "Custom Project",
		"created_at": 1000,
		"modified_at": 1000,
		"user_custom_data": "must_preserve"
	}
	var migrated := SchemaMigration.migrate(old_manifest, "0.1.0", "1.0.0")
	_assert(migrated.get("user_custom_data", "") == "must_preserve", "Custom fields preserved during migration")


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + msg)
	else:
		_failed += 1
		_errors.append(msg)
		printerr("  FAIL: " + msg)
