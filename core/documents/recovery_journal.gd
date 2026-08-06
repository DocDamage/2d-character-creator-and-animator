# RecoveryJournalService — Records save and autosave operations in a recovery journal
# Path: core/documents/recovery_journal.gd
class_name RecoveryJournalService
extends RefCounted

const JOURNAL_PATH := "user://recovery_journal.json"
const MAX_ENTRIES := 50


static func record_event(event_type: String, file_path: String, hash_value: String = "", bytes_written: int = 0) -> Dictionary:
	var entry := {
		"event_type": event_type,
		"file_path": file_path,
		"timestamp": Time.get_unix_time_from_system(),
		"hash": hash_value,
		"bytes": bytes_written
	}
	var entries := get_journal_entries()
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	_save_journal(entries)
	return entry


static func get_journal_entries() -> Array[Dictionary]:
	if not FileAccess.file_exists(JOURNAL_PATH):
		return []
	var f := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
	if f == null:
		return []
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_ARRAY:
			var typed_res: Array[Dictionary] = []
			for item in data:
				if typeof(item) == TYPE_DICTIONARY:
					typed_res.append(item)
			return typed_res
	return []


static func get_latest_entry(event_type: String = "") -> Dictionary:
	var entries := get_journal_entries()
	for i in range(entries.size() - 1, -1, -1):
		if event_type.is_empty() or entries[i].get("event_type", "") == event_type:
			return entries[i]
	return {}


static func clear_journal() -> void:
	if FileAccess.file_exists(JOURNAL_PATH):
		DirAccess.remove_absolute(JOURNAL_PATH)


static func _save_journal(entries: Array[Dictionary]) -> void:
	var f := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries, "\t"))
		f.close()
