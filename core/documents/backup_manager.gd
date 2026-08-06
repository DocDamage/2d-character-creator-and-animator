# BackupManager — Manages rolling project backups
# Path: core/documents/backup_manager.gd
class_name BackupManager
extends RefCounted

const DEFAULT_MAX_BACKUPS := 10
const BACKUP_EXTENSION := ".bak"


static func create_backup(project_path: String, max_backups: int = DEFAULT_MAX_BACKUPS) -> String:
	if not FileAccess.file_exists(project_path):
		return ""
	rotate_backups(project_path, max_backups)
	var backup_path := get_backup_path(project_path, 0)
	if DirAccess.copy_absolute(project_path, backup_path) == OK:
		return backup_path
	return ""


static func rotate_backups(project_path: String, max_backups: int = DEFAULT_MAX_BACKUPS) -> void:
	var existing := get_backups(project_path)
	while existing.size() >= max_backups:
		var oldest: String = existing.pop_back()
		if FileAccess.file_exists(oldest):
			DirAccess.remove_absolute(oldest)

	for i in range(existing.size() - 1, -1, -1):
		var src: String = existing[i]
		var dst := get_backup_path(project_path, i + 1)
		if FileAccess.file_exists(src):
			DirAccess.rename_absolute(src, dst)


static func get_backup_path(project_path: String, index: int) -> String:
	if index == 0:
		return project_path + BACKUP_EXTENSION
	return project_path + BACKUP_EXTENSION + "." + str(index)


static func get_backups(project_path: String) -> Array[String]:
	var results: Array[String] = []
	var base_file := project_path.get_file()
	var dir_path := project_path.get_base_dir()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		var full_path := dir_path.path_join(fn)
		if FileAccess.file_exists(full_path) and fn.begins_with(base_file) and BACKUP_EXTENSION in fn:
			if fn != base_file:
				results.append(full_path)
		fn = dir.get_next()
	dir.list_dir_end()

	results.sort()
	return results
