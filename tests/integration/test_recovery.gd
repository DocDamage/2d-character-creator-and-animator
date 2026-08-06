# Integration Test Suite — Recovery Journal & Autosave (REQ-DOC-007)
extends Node

const RecoveryJournalService = preload("res://core/documents/recovery_journal.gd")
const TEST_FILE := "user://test_recovery_project.chrproj"

var _passed := 0
var _failed := 0
var _errors: Array[String] = []


func run_all_tests() -> Dictionary:
	_passed = 0
	_failed = 0
	_errors.clear()

	RecoveryJournalService.clear_journal()

	print("[TEST 20] Autosave & Recovery Journal Workflows (REQ-DOC-007)...")
	test_record_journal_event()
	test_journal_filtering()
	test_journal_max_entries()
	test_journal_clear()

	RecoveryJournalService.clear_journal()
	return {"passed": _passed, "failed": _failed, "errors": _errors}


func test_record_journal_event() -> void:
	var entry := RecoveryJournalService.record_event("manual_save", TEST_FILE, "abc123hash", 1024)
	_assert(entry.get("event_type", "") == "manual_save", "Journal recorded event_type")
	_assert(entry.get("file_path", "") == TEST_FILE, "Journal recorded file_path")

	var entries := RecoveryJournalService.get_journal_entries()
	_assert(entries.size() >= 1, "Journal contains recorded entry")


func test_journal_filtering() -> void:
	RecoveryJournalService.record_event("autosave", TEST_FILE + ".auto", "hashauto", 512)
	var latest_auto := RecoveryJournalService.get_latest_entry("autosave")
	_assert(latest_auto.get("event_type", "") == "autosave", "get_latest_entry filters by autosave type")


func test_journal_max_entries() -> void:
	for i in range(60):
		RecoveryJournalService.record_event("test_event", TEST_FILE, "hash_%d" % i, i * 10)
	var entries := RecoveryJournalService.get_journal_entries()
	_assert(entries.size() <= RecoveryJournalService.MAX_ENTRIES, "Journal entry count capped at MAX_ENTRIES")


func test_journal_clear() -> void:
	RecoveryJournalService.clear_journal()
	var entries := RecoveryJournalService.get_journal_entries()
	_assert(entries.is_empty(), "Journal is empty after clear_journal")


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: " + msg)
	else:
		_failed += 1
		_errors.append(msg)
		printerr("  FAIL: " + msg)
