# Imports artwork and companion metadata from the legacy Character Creator 2D install.
# The importer is copy-only: it preserves the source folders and records hashes/provenance.
extends SceneTree

const DEFAULT_SOURCE := "C:/Users/dferr/OneDrive/Desktop/Character Creator 2D"
const DEFAULT_DESTINATION := "res://assets/imported/character_creator_2d"
const SOURCE_FOLDERS := ["Weapons Sprites to Import", "Texture Guides", "Saved Characters"]
const IMPORTABLE_EXTENSIONS := ["png", "gif", "cc2d", "json", "csv", "txt"]


func _init() -> void:
	var source := _absolute(_argument("--source", DEFAULT_SOURCE)).simplify_path()
	var destination := _absolute(_argument("--destination", DEFAULT_DESTINATION)).simplify_path()
	var result := _import(source, destination)
	print(JSON.stringify(result, "\t"))
	quit(0 if bool(result.get("success", false)) else 1)


func _import(source_root: String, destination_root: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(source_root):
		return _failure("Legacy Character Creator 2D source folder is unavailable: %s" % source_root)
	if source_root == destination_root or destination_root.begins_with(source_root.trim_suffix("/") + "/"):
		return _failure("Import destination must not be inside the legacy source folder.")
	if DirAccess.make_dir_recursive_absolute(destination_root) != OK:
		return _failure("Could not create import destination: %s" % destination_root)
	var files: Array[String] = []
	for folder_name in SOURCE_FOLDERS:
		var folder := source_root.path_join(folder_name)
		_collect_importable_files(folder, files)
	files.sort()
	var entries: Array = []
	var copied := 0
	var skipped := 0
	var conflicts := 0
	var errors: Array[String] = []
	for source_path in files:
		var relative := _relative_to(source_root, source_path)
		var source_hash := _hash(source_path)
		var target := destination_root.path_join(relative)
		var status := "copied"
		if FileAccess.file_exists(target):
			if _hash(target) == source_hash:
				status = "already_present"
				skipped += 1
			else:
				target = _conflict_target(target, source_hash)
				status = "copied_name_conflict"
				conflicts += 1
		if status != "already_present":
			if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK or DirAccess.copy_absolute(source_path, target) != OK:
				errors.append("Could not copy: %s" % relative)
				continue
			copied += 1
		entries.append({
			"source_relative_path": relative.replace("\\", "/"),
			"destination_relative_path": _relative_to(destination_root, target).replace("\\", "/"),
			"sha256": source_hash,
			"bytes": _size(source_path),
			"extension": source_path.get_extension().to_lower(),
			"status": status,
			"license_status": "unknown_requires_review",
		})
	var manifest := {
		"schema_version": "1.0.0",
		"importer": "paper-quest-legacy-character-creator-import/1.0.0",
		"source_label": "Character Creator 2D",
		"source_folders": SOURCE_FOLDERS,
		"copy_only": true,
		"license_notice": "Source licenses were not established by this import. Review each asset before redistribution.",
		"imported_at": Time.get_datetime_string_from_system(true, true),
		"files": entries,
	}
	var manifest_path := destination_root.path_join("IMPORT_MANIFEST.json")
	if not _write_manifest(manifest_path, manifest): errors.append("Could not write the import manifest.")
	return {"success": errors.is_empty(), "source": source_root, "destination": destination_root, "candidate_count": files.size(), "copied": copied, "already_present": skipped, "name_conflicts": conflicts, "manifest": manifest_path, "errors": errors}


func _collect_importable_files(folder: String, output: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(folder): return
	var directory := DirAccess.open(folder)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := folder.path_join(entry)
		if directory.current_is_dir():
			_collect_importable_files(path, output)
		elif path.get_extension().to_lower() in IMPORTABLE_EXTENSIONS:
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _conflict_target(target: String, hash: String) -> String:
	var extension := target.get_extension()
	var base := target.get_basename()
	var suffix := "--" + hash.substr(0, 10)
	var candidate := base + suffix + ("." + extension if not extension.is_empty() else "")
	var index := 2
	while FileAccess.file_exists(candidate):
		candidate = base + suffix + "-" + str(index) + ("." + extension if not extension.is_empty() else "")
		index += 1
	return candidate


func _argument(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if str(args[index]) == flag: return str(args[index + 1])
	return fallback


func _relative_to(root: String, path: String) -> String:
	var normalized_root := root.replace("\\", "/").trim_suffix("/") + "/"
	return path.replace("\\", "/").trim_prefix(normalized_root)


func _hash(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	var hash := context.finish().hex_encode()
	file.close()
	return hash


func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return 0
	var length := file.get_length()
	file.close()
	return length


func _write_manifest(path: String, manifest: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return true


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _failure(error: String) -> Dictionary:
	return {"success": false, "errors": [error]}
