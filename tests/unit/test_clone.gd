# Unit Test Suite — Clone & Save-As Workflows (REQ-DOC-010)
extends Node

const ProjectCloner = preload("res://core/documents/project_cloner.gd")
const ProjectSchema = preload("res://core/documents/project_schema.gd")

const TEST_DIR := "user://test_clone/"
const TEST_SAVE_AS := TEST_DIR + "save_as_project.chrproj"

var _passed := 0
var _failed := 0
var _errors: Array[String] = []


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	_setup_test_dir()

	print("[TEST 23] Clone & Save-As Workflows (REQ-DOC-010)...")
	test_clone_project_preserves_structure()
	test_clone_project_generates_new_ids()
	test_save_as_creates_valid_file()

	_cleanup_test_dir()
	return {"passed": _passed, "failed": _failed, "errors": _errors}


func test_clone_project_preserves_structure() -> void:
	var default_manifest := ProjectSchema.create_default_manifest("Original Project")
	var cloned := ProjectCloner.clone_project(default_manifest, "Cloned Project")
	_assert(cloned["project_name"] == "Cloned Project", "Cloned project name updated")
	_assert(cloned.get("cloned_from", "") == default_manifest["project_id"], "cloned_from metadata references original ID")
	_assert(ProjectSchema.is_valid(cloned), "Cloned manifest is valid against ProjectSchema")


func test_clone_project_generates_new_ids() -> void:
	var default_manifest := ProjectSchema.create_default_manifest("Original Project")
	var cloned := ProjectCloner.clone_project(default_manifest)
	_assert(cloned["project_id"] != default_manifest["project_id"], "Cloned project_id is distinct from original")


func test_save_as_creates_valid_file() -> void:
	var default_manifest := ProjectSchema.create_default_manifest("Source Project")
	var success := ProjectCloner.save_as(default_manifest, TEST_SAVE_AS, "Saved As Project")
	_assert(success, "save_as returned true")
	_assert(FileAccess.file_exists(TEST_SAVE_AS), "Save-As file created on disk")


func _setup_test_dir() -> void:
	_cleanup_test_dir()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func _cleanup_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var da := DirAccess.open(TEST_DIR)
		if da != null:
			da.list_dir_begin()
			var fn := da.get_next()
			while fn != "":
				var full := TEST_DIR.path_join(fn)
				if FileAccess.file_exists(full):
					DirAccess.remove_absolute(full)
				fn = da.get_next()
			da.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + msg)
	else:
		_failed += 1
		_errors.append(msg)
		printerr("  FAIL: " + msg)
