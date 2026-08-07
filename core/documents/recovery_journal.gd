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


static func begin_session() -> Dictionary:
	return record_event("session_started", "")


static func complete_session() -> Dictionary:
	return record_event("clean_shutdown", "")


static func get_pending_recoveries() -> Array[Dictionary]:
	var entries := get_journal_entries()
	var last_clean_shutdown := -1
	for entry in entries:
		if str(entry.get("event_type", "")) == "clean_shutdown":
			last_clean_shutdown = int(entry.get("timestamp", -1))
	var pending: Array[Dictionary] = []
	for entry in entries:
		if str(entry.get("event_type", "")) != "autosave": continue
		if int(entry.get("timestamp", 0)) <= last_clean_shutdown: continue
		var path := str(entry.get("file_path", ""))
		if path.is_empty() or not FileAccess.file_exists(path): continue
		var candidate := entry.duplicate(true)
		candidate["preview"] = get_project_preview(path)
		pending.append(candidate)
	pending.sort_custom(func(a, b): return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0)))
	return pending


static func get_project_preview(path: String) -> Dictionary:
	var preview := {"name": path.get_file().get_basename(), "layers": 0, "valid": false}
	if path.is_empty() or not FileAccess.file_exists(path): return preview
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return preview
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary:
		var data: Dictionary = json.get_data()
		preview["name"] = str(data.get("project_name", preview.name))
		var authoring: Dictionary = data.get("metadata", {}).get("character_authoring", {})
		preview["layers"] = (authoring.get("parts", {}) as Dictionary).size()
		preview["valid"] = true
	file.close()
	return preview


static func clear_journal() -> void:
	if FileAccess.file_exists(JOURNAL_PATH):
		DirAccess.remove_absolute(JOURNAL_PATH)


static func _save_journal(entries: Array[Dictionary]) -> void:
	var f := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries, "\t"))
		f.close()
