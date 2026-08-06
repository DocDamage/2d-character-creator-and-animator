# CorruptProjectRecovery — Quarantines corrupt files and restores valid backups
# Path: core/documents/corrupt_project_recovery.gd
class_name CorruptProjectRecovery
extends RefCounted

const ProjectSchema = preload("res://core/documents/project_schema.gd")
const BackupManager = preload("res://core/documents/backup_manager.gd")


static func quarantine_file(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		return ""
	var timestamp := str(Time.get_unix_time_from_system())
	var quarantine_path := file_path + "." + timestamp + ".corrupt"
	if DirAccess.rename_absolute(file_path, quarantine_path) == OK:
		return quarantine_path
	return ""


static func get_recovery_candidates(project_path: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var backups := BackupManager.get_backups(project_path)
	
	# Check autosave file as candidate as well
	var autosave_path := project_path.get_basename() + ".autosave.json"
	if FileAccess.file_exists(autosave_path) and autosave_path not in backups:
		backups.append(autosave_path)

	for b_path in backups:
		if FileAccess.file_exists(b_path):
			var f := FileAccess.open(b_path, FileAccess.READ)
			if f != null:
				var json := JSON.new()
				var is_valid := false
				if json.parse(f.get_as_text()) == OK:
					var data = json.get_data()
					if typeof(data) == TYPE_DICTIONARY:
						is_valid = ProjectSchema.is_valid(data)
				f.close()
				candidates.append({
					"path": b_path,
					"is_valid": is_valid
				})
	return candidates


static func recover_from_backup(corrupt_path: String, backup_path: String) -> bool:
	if not FileAccess.file_exists(backup_path):
		return false
	if FileAccess.file_exists(corrupt_path):
		quarantine_file(corrupt_path)
	return DirAccess.copy_absolute(backup_path, corrupt_path) == OK
