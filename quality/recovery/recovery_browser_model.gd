# RecoveryBrowserModel -- Presents journal/backups and performs a deliberate, recoverable restore.
class_name RecoveryBrowserModel
extends RefCounted

const CorruptRecoveryScript = preload("res://core/documents/corrupt_project_recovery.gd")
const JournalScript = preload("res://core/documents/recovery_journal.gd")

var project_path: String = ""
var candidates: Array = []


func scan(path: String) -> Array:
	project_path = path
	candidates = CorruptRecoveryScript.get_recovery_candidates(path)
	for entry in JournalScript.get_journal_entries():
		var record := entry as Dictionary
		if str(record.get("file_path", "")).begins_with(path.get_basename()):
			var journal_path := str(record.get("file_path", ""))
			if FileAccess.file_exists(journal_path) and not _has_path(journal_path): candidates.append({"path": journal_path, "is_valid": true, "journal_event": record.get("event_type", "")})
	return candidates.duplicate(true)


func restore(candidate_path: String) -> Dictionary:
	if project_path.is_empty() or not _has_path(candidate_path): return {"success": false, "error": "candidate is not available"}
	var restored := CorruptRecoveryScript.recover_from_backup(project_path, candidate_path)
	return {"success": restored, "project_path": project_path, "candidate_path": candidate_path, "message": "Recovered project from selected candidate." if restored else "Recovery failed without modifying the selected candidate."}


func _has_path(path: String) -> bool:
	for candidate in candidates:
		if str((candidate as Dictionary).get("path", "")) == path: return true
	return false
