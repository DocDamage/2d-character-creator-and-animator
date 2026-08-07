# ProjectSnapshotService -- Portable, user-owned project milestones.
#
# A manual snapshot deliberately does not share an asset folder with its live
# project.  That makes it useful after artwork is moved, replaced, or deleted
# outside the editor, and keeps it distinct from Undo and rolling autosaves.
class_name ProjectSnapshotService
extends RefCounted

const SNAPSHOT_PROJECT_FILE := "snapshot.chrproj"
const SNAPSHOT_INFO_FILE := "snapshot.json"


func create(project_path: String, source_manifest: Dictionary, display_name: String, note: String = "", kind: String = "manual") -> Dictionary:
	if project_path.strip_edges().is_empty() or project_path.begins_with("res://"):
		return _failure("Bundled samples are read-only. Use Save As before creating a snapshot.")
	if source_manifest.is_empty():
		return _failure("There is no project data to snapshot.")
	var root := get_snapshot_root(project_path)
	var timestamp := Time.get_unix_time_from_system()
	var clean_name := _safe_name(display_name)
	if clean_name.is_empty(): clean_name = "Snapshot"
	var snapshot_id := "%d_%s" % [timestamp, clean_name]
	var destination := root.path_join(snapshot_id)
	var suffix := 2
	while DirAccess.dir_exists_absolute(_absolute(destination)):
		destination = root.path_join("%s_%d" % [snapshot_id, suffix])
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(_absolute(destination)) != OK:
		return _failure("Could not create the snapshot folder.")
	var snapshot_manifest := source_manifest.duplicate(true)
	# Each snapshot owns a private asset tree.  The manifest is rewritten to
	# those copied files so deleting or moving the live project artwork cannot
	# invalidate a named milestone.
	var copy_report := _copy_assets(snapshot_manifest, destination.path_join("assets"))
	if not copy_report.get("success", false):
		_delete_tree(destination)
		return copy_report
	var metadata: Dictionary = snapshot_manifest.get("metadata", {}).duplicate(true)
	metadata["snapshot"] = {
		"id": destination.get_file(), "name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else clean_name,
		"note": note.strip_edges(), "kind": kind, "timestamp": timestamp,
	}
	snapshot_manifest["metadata"] = metadata
	var project_file := destination.path_join(SNAPSHOT_PROJECT_FILE)
	if not SerializationService.save_project(snapshot_manifest, project_file):
		_delete_tree(destination)
		return _failure("The snapshot project file could not be written.")
	var info := _snapshot_info_from_manifest(snapshot_manifest, destination, timestamp, display_name, note, kind)
	if not _write_json(destination.path_join(SNAPSHOT_INFO_FILE), info):
		_delete_tree(destination)
		return _failure("The snapshot metadata could not be written.")
	return {"success": true, "errors": [], "id": destination.get_file(), "path": destination, "project_path": project_file, "snapshot": info}


func list(project_path: String) -> Array:
	var result: Array = []
	if project_path.strip_edges().is_empty() or project_path.begins_with("res://"):
		return result
	var root := get_snapshot_root(project_path)
	var directory := DirAccess.open(_absolute(root))
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and directory.current_is_dir():
			var path := root.path_join(entry)
			var info := _read_json(path.path_join(SNAPSHOT_INFO_FILE))
			if info.is_empty():
				info = {"id": entry, "name": entry.replace("_", " "), "timestamp": _timestamp_from_id(entry), "kind": "manual"}
			info["id"] = str(info.get("id", entry))
			info["path"] = path
			info["project_path"] = path.path_join(SNAPSHOT_PROJECT_FILE)
			info["valid"] = FileAccess.file_exists(path.path_join(SNAPSHOT_PROJECT_FILE))
			result.append(info)
		entry = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0)))
	return result


func restore(project_path: String, snapshot_id: String, active_manifest: Dictionary) -> Dictionary:
	if project_path.strip_edges().is_empty() or project_path.begins_with("res://"):
		return _failure("Bundled samples are read-only. Use Save As before restoring a snapshot.")
	var snapshot := get_snapshot(project_path, snapshot_id)
	if snapshot.is_empty() or not bool(snapshot.get("valid", false)):
		return _failure("The selected snapshot is missing or incomplete.")
	var loaded: Dictionary = SerializationService.load_project(str(snapshot.get("project_path", "")))
	if loaded.is_empty():
		return _failure("The selected snapshot could not be read.")
	# The caller owns this pre-restore copy so the restore operation is always
	# recoverable even if its target had never been manually saved before.
	var before_name := "Before restoring %s" % str(snapshot.get("name", snapshot_id))
	var before_report := create(project_path, active_manifest, before_name, "Automatic recovery point before restore.", "before_restore")
	if not before_report.get("success", false):
		return before_report
	var restored := loaded.duplicate(true)
	# Do not overwrite the live asset tree in place.  A restore receives a new,
	# project-owned folder beneath the active project asset root; the restored
	# manifest then points only at those copies.  This keeps both the automatic
	# pre-restore milestone and any current artwork recoverable.
	var restored_root := _asset_root_for_project(project_path).path_join("restored_%d" % Time.get_unix_time_from_system())
	var copy_report := _copy_assets(restored, restored_root)
	if not copy_report.get("success", false):
		return copy_report
	var metadata: Dictionary = restored.get("metadata", {}).duplicate(true)
	metadata.erase("snapshot")
	metadata["last_restored_snapshot"] = {"id": snapshot_id, "timestamp": Time.get_unix_time_from_system(), "pre_restore_snapshot_id": str(before_report.get("id", ""))}
	restored["metadata"] = metadata
	if not SerializationService.save_project(restored, project_path):
		return _failure("The restored project could not be saved.")
	return {"success": true, "errors": [], "manifest": restored, "before_restore_snapshot": before_report.get("snapshot", {}), "snapshot": snapshot}


func delete(project_path: String, snapshot_id: String) -> Dictionary:
	if project_path.strip_edges().is_empty() or project_path.begins_with("res://"):
		return _failure("Bundled samples are read-only. Use Save As before deleting snapshots.")
	var snapshot := get_snapshot(project_path, snapshot_id)
	if snapshot.is_empty():
		return _failure("The selected snapshot no longer exists.")
	var root := get_snapshot_root(project_path)
	var target := str(snapshot.get("path", ""))
	if not _is_child_path(target, root):
		return _failure("The selected snapshot is outside this project’s snapshot folder.")
	if not _delete_tree(target):
		return _failure("The snapshot could not be deleted.")
	return {"success": true, "errors": [], "id": snapshot_id}


func get_snapshot(project_path: String, snapshot_id: String) -> Dictionary:
	for snapshot in list(project_path):
		if str((snapshot as Dictionary).get("id", "")) == snapshot_id:
			return (snapshot as Dictionary).duplicate(true)
	return {}


func get_snapshot_root(project_path: String) -> String:
	return project_path + ".snapshots"


func reveal(project_path: String, snapshot_id: String = "") -> Dictionary:
	var target := get_snapshot_root(project_path)
	if not snapshot_id.is_empty():
		var snapshot := get_snapshot(project_path, snapshot_id)
		if snapshot.is_empty(): return _failure("The selected snapshot no longer exists.")
		target = str(snapshot.get("path", target))
	if not DirAccess.dir_exists_absolute(_absolute(target)):
		return _failure("There is no snapshot folder to reveal yet.")
	return {"success": OS.shell_open(_absolute(target)) == OK, "errors": []}


func _copy_assets(target_manifest: Dictionary, target_root: String) -> Dictionary:
	var objects: Dictionary = target_manifest.get("objects", {})
	var assets: Dictionary = objects.get("assets", {}).duplicate(true)
	for asset_id in assets:
		var asset: Dictionary = assets[asset_id].duplicate(true)
		var source := str(asset.get("path", ""))
		if source.is_empty() or not FileAccess.file_exists(source):
			return _failure("Missing project asset: " + source)
		var category := str(asset.get("asset_type", asset.get("type", "asset"))).validate_filename()
		if category.is_empty(): category = "assets"
		var target_dir := target_root.path_join(category)
		if DirAccess.make_dir_recursive_absolute(_absolute(target_dir)) != OK and not DirAccess.dir_exists_absolute(_absolute(target_dir)):
			return _failure("Could not create a portable snapshot asset folder.")
		var target := target_dir.path_join(str(asset_id).validate_filename() + "_" + source.get_file().validate_filename())
		if _absolute(source) != _absolute(target) and DirAccess.copy_absolute(_absolute(source), _absolute(target)) != OK:
			return _failure("Could not copy project asset: " + source)
		asset["path"] = target
		assets[asset_id] = asset
	objects["assets"] = assets
	target_manifest["objects"] = objects
	return {"success": true, "errors": []}


func _snapshot_info_from_manifest(manifest: Dictionary, folder: String, timestamp: int, display_name: String, note: String, kind: String) -> Dictionary:
	var authoring: Dictionary = manifest.get("metadata", {}).get("character_authoring", {})
	var characters: Dictionary = manifest.get("objects", {}).get("characters", {})
	var active_id := str(authoring.get("active_character_id", ""))
	var assembly: Dictionary = characters.get(active_id, {}).get("assembly", {})
	return {
		"id": folder.get_file(), "name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else folder.get_file(),
		"note": note.strip_edges(), "kind": kind, "timestamp": timestamp,
		"preview": {"project_name": str(manifest.get("project_name", "Untitled")), "character_name": str(assembly.get("display_name", "")), "canvas": authoring.get("canvas", {}).duplicate(true), "asset_count": (manifest.get("objects", {}).get("assets", {}) as Dictionary).size(), "clip_count": (manifest.get("objects", {}).get("animations", {}) as Dictionary).size()},
	}


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _delete_tree(path: String) -> bool:
	var absolute := _absolute(path)
	var directory := DirAccess.open(absolute)
	if directory == null: return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute.path_join(entry)
			if directory.current_is_dir():
				if not _delete_tree(child):
					directory.list_dir_end()
					return false
			elif DirAccess.remove_absolute(child) != OK:
				directory.list_dir_end()
				return false
		entry = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(absolute) == OK


func _is_child_path(path: String, root: String) -> bool:
	var absolute_path := _absolute(path).replace("\\", "/").to_lower()
	var absolute_root := _absolute(root).replace("\\", "/").to_lower().trim_suffix("/") + "/"
	return absolute_path.begins_with(absolute_root)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _asset_root_for_project(project_path: String) -> String:
	return project_path.get_base_dir().path_join(project_path.get_file().get_basename() + "_assets")


func _safe_name(value: String) -> String:
	return value.strip_edges().replace(" ", "_").validate_filename().left(72)


func _timestamp_from_id(value: String) -> int:
	var prefix := value.split("_", false, 1)
	return int(prefix[0]) if not prefix.is_empty() else 0


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message]}
