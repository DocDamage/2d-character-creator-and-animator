# Integration Test Suite — Rolling Backups Workflows (REQ-DOC-006)
extends Node

const BackupManager = preload("res://core/documents/backup_manager.gd")
const TEST_DIR := "user://test_backups/"
const TEST_FILE := TEST_DIR + "project.chrproj"

var _passed := 0
var _failed := 0
var _errors: Array[String] = []


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	_setup_test_dir()

	print("[TEST 19] Rolling Backups Workflows (REQ-DOC-006)...")
	test_backup_creation()
	test_backup_rotation()
	test_max_backups_limit()
	test_nonexistent_file_backup()

	_cleanup_test_dir()
	return {"passed": _passed, "failed": _failed, "errors": _errors}


func test_backup_creation() -> void:
	_create_dummy_file(TEST_FILE, "version 1")
	var backup_path := BackupManager.create_backup(TEST_FILE, 5)
	_assert(not backup_path.is_empty(), "Backup creation returned valid path")
	_assert(FileAccess.file_exists(backup_path), "Backup file created on disk")
	var backups := BackupManager.get_backups(TEST_FILE)
	_assert(backups.size() == 1, "Backup count is 1 after single backup")


func test_backup_rotation() -> void:
	_cleanup_test_dir()
	_setup_test_dir()
	for i in range(3):
		_create_dummy_file(TEST_FILE, "content %d" % i)
		BackupManager.create_backup(TEST_FILE, 5)

	var backups := BackupManager.get_backups(TEST_FILE)
	_assert(backups.size() == 3, "Rotated backups count is 3")


func test_max_backups_limit() -> void:
	_cleanup_test_dir()
	_setup_test_dir()
	const MAX := 3
	for i in range(6):
		_create_dummy_file(TEST_FILE, "content iteration %d" % i)
		BackupManager.create_backup(TEST_FILE, MAX)

	var backups := BackupManager.get_backups(TEST_FILE)
	_assert(backups.size() <= MAX, "Backup count capped at MAX (%d <= %d)" % [backups.size(), MAX])


func test_nonexistent_file_backup() -> void:
	var res := BackupManager.create_backup(TEST_DIR + "nonexistent.chrproj")
	_assert(res.is_empty(), "Backup of non-existent file returns empty string")


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
