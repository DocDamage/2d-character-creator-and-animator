# WatchFolderService -- Explicitly approved source-layer polling with safe re-import routing.
class_name WatchFolderService
extends RefCounted

var entries: Array = []


func configure(value: Array) -> void:
	entries = value.duplicate(true)


func to_dict() -> Array:
	return entries.duplicate(true)


func add_source(source_path: String, part_id: String, approved: bool = false, label: String = "") -> Dictionary:
	var clean_path := source_path.strip_edges()
	if clean_path.is_empty() or part_id.strip_edges().is_empty(): return {"success": false, "errors": ["A source file and character part are required."]}
	for entry in entries:
		if str((entry as Dictionary).get("source_path", "")) == clean_path and str((entry as Dictionary).get("part_id", "")) == part_id:
			return {"success": false, "errors": ["That source is already watched for this part."]}
	entries.append({"source_path": clean_path, "part_id": part_id.strip_edges(), "label": label.strip_edges() if not label.strip_edges().is_empty() else clean_path.get_file(), "approved": approved, "checksum": _checksum(clean_path), "last_seen_unix": Time.get_unix_time_from_system()})
	return {"success": true, "entries": to_dict()}


func scan_once() -> Dictionary:
	var changes: Array = []
	var missing: Array = []
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] as Dictionary
		var path := str(entry.get("source_path", ""))
		if path.is_empty() or not FileAccess.file_exists(_absolute(path)):
			missing.append({"index": index, "entry": entry.duplicate(true)})
			continue
		var checksum := _checksum(path)
		if checksum != str(entry.get("checksum", "")):
			changes.append({"index": index, "entry": entry.duplicate(true), "checksum": checksum, "approved": bool(entry.get("approved", false))})
	return {"changes": changes, "missing": missing, "safe_to_reimport": _approved_changes(changes)}


func apply_approved(session) -> Dictionary:
	if session == null or not is_instance_valid(session): return {"success": false, "errors": ["Open a character project before re-importing watched artwork."]}
	var scan := scan_once()
	var applied: Array = []
	var skipped: Array = []
	for change in scan.get("changes", []) as Array:
		var record: Dictionary = change as Dictionary
		var entry: Dictionary = record.get("entry", {}) as Dictionary
		if not bool(entry.get("approved", false)):
			skipped.append({"entry": entry, "reason": "awaiting artist approval"})
			continue
		var report: Dictionary = session.replace_layer_art(str(entry.get("part_id", "")), str(entry.get("source_path", "")))
		if bool(report.get("success", false)):
			var index := int(record.get("index", -1))
			if index >= 0 and index < entries.size():
				var updated: Dictionary = entries[index] as Dictionary
				updated["checksum"] = str(record.get("checksum", ""))
				updated["last_seen_unix"] = Time.get_unix_time_from_system()
				entries[index] = updated
			applied.append({"entry": entry, "report": report})
		else:
			skipped.append({"entry": entry, "reason": str(report.get("errors", ["re-import failed"])[0])})
	return {"success": skipped.is_empty(), "applied": applied, "skipped": skipped, "missing": scan.get("missing", []), "entries": to_dict()}


func set_approved(source_path: String, part_id: String, approved: bool) -> bool:
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] as Dictionary
		if str(entry.get("source_path", "")) == source_path and str(entry.get("part_id", "")) == part_id:
			entry["approved"] = approved
			entries[index] = entry
			return true
	return false


func _approved_changes(changes: Array) -> Array:
	var result: Array = []
	for change in changes:
		if bool((change as Dictionary).get("approved", false)): result.append(change)
	return result


func _checksum(path: String) -> String:
	return FileAccess.get_md5(_absolute(path)) if FileAccess.file_exists(_absolute(path)) else ""


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
