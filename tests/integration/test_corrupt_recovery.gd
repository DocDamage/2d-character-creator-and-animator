# Integration Test Suite — Corrupt Project Recovery (REQ-DOC-009)
extends Node

const CorruptProjectRecovery = preload("res://core/documents/corrupt_project_recovery.gd")
const BackupManager = preload("res://core/documents/backup_manager.gd")
const ProjectSchema = preload("res://core/documents/project_schema.gd")

const TEST_DIR := "user://test_corrupt_recovery/"
const CORRUPT_PROJECT := TEST_DIR + "corrupt.chrproj"

var _passed := 0
var _failed := 0
var _errors: Array[String] = []


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	_setup_test_dir()

	print("[TEST 22] Corrupt-Project Recovery Workflows (REQ-DOC-009)...")
	test_quarantine_file()
	test_get_recovery_candidates()
	test_recover_from_backup()

	_cleanup_test_dir()
	return {"passed": _passed, "failed": _failed, "errors": _errors}


func test_quarantine_file() -> void:
	_create_dummy_file(CORRUPT_PROJECT, "{ invalid json }")
	var q_path := CorruptProjectRecovery.quarantine_file(CORRUPT_PROJECT)
	_assert(not q_path.is_empty(), "Quarantine path returned non-empty string")
	_assert(FileAccess.file_exists(q_path), "Quarantined file exists on disk")
	_assert(not FileAccess.file_exists(CORRUPT_PROJECT), "Original corrupt file moved")


func test_get_recovery_candidates() -> void:
	_cleanup_test_dir()
	_setup_test_dir()
	_create_dummy_file(CORRUPT_PROJECT, "valid master")
	BackupManager.create_backup(CORRUPT_PROJECT, 3)

	# Overwrite master with corrupt data
	_create_dummy_file(CORRUPT_PROJECT, "{ corrupt json }")

	var candidates := CorruptProjectRecovery.get_recovery_candidates(CORRUPT_PROJECT)
	_assert(candidates.size() >= 1, "Found at least 1 recovery candidate backup")


func test_recover_from_backup() -> void:
	_cleanup_test_dir()
	_setup_test_dir()

	# Create a valid file, make backup, then corrupt main file
	var valid_manifest := JSON.stringify(ProjectSchema.create_default_manifest("Valid Project"), "\t")
	_create_dummy_file(CORRUPT_PROJECT, valid_manifest)
	var backup_path := BackupManager.create_backup(CORRUPT_PROJECT, 3)

	_create_dummy_file(CORRUPT_PROJECT, "broken json text")

	var success := CorruptProjectRecovery.recover_from_backup(CORRUPT_PROJECT, backup_path)
	_assert(success, "recover_from_backup returned true")
	_assert(FileAccess.file_exists(CORRUPT_PROJECT), "Main file restored")

	var f := FileAccess.open(CORRUPT_PROJECT, FileAccess.READ)
	_assert(f != null and f.get_as_text() == valid_manifest, "Restored content matches valid backup manifest")
	if f != null:
		f.close()


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
				if not da.current_is_dir():
					DirAccess.remove_absolute(TEST_DIR.path_join(fn))
				fn = da.get_next()
			da.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)


func _create_dummy_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + msg)
	else:
		_failed += 1
		_errors.append(msg)
		printerr("  FAIL: " + msg)
