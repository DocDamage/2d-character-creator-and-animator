# AssetPackService -- Portable ZIP packs with manifest-first inspection and traversal-safe extraction.
class_name AssetPackService
extends RefCounted

const FORMAT := "modular_character_asset_pack"
const VERSION := "1.0.0"


func export_pack(manifest: Dictionary, output_path: String, asset_ids: Array = []) -> Dictionary:
	var assets: Dictionary = manifest.get("objects", {}).get("assets", {}) as Dictionary
	var selected: Array = asset_ids.duplicate() if not asset_ids.is_empty() else assets.keys()
	selected.sort()
	var absolute := _absolute(output_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return {"success": false, "errors": ["Could not create asset-pack directory."]}
	var zip := ZIPPacker.new()
	if zip.open(absolute) != OK: return {"success": false, "errors": ["Could not create asset pack."]}
	var records: Dictionary = {}
	var errors: Array = []
	for asset_id in selected:
		var asset: Dictionary = assets.get(asset_id, {}) as Dictionary
		var source := str(asset.get("path", ""))
		if source.is_empty() or not FileAccess.file_exists(_absolute(source)):
			errors.append("Missing asset: " + str(asset_id))
			continue
		var archive_path := "assets/%s_%s" % [str(asset_id).validate_filename(), source.get_file().validate_filename()]
		var file := FileAccess.open(_absolute(source), FileAccess.READ)
		if file == null or zip.start_file(archive_path) != OK:
			if file != null: file.close()
			errors.append("Could not add asset: " + str(asset_id))
			continue
		var write_error := zip.write_file(file.get_buffer(file.get_length()))
		file.close()
		if write_error != OK:
			errors.append("Could not write asset: " + str(asset_id))
			continue
		var record := asset.duplicate(true)
		record["package_path"] = archive_path
		record.erase("path")
		records[str(asset_id)] = record
	var package := {"format": FORMAT, "format_version": VERSION, "project_id": str(manifest.get("project_id", "")), "assets": records, "created_at": Time.get_unix_time_from_system()}
	if zip.start_file("asset_pack.json") != OK or zip.write_file(JSON.stringify(package, "\t", true, false).to_utf8_buffer()) != OK: errors.append("Could not write asset-pack manifest.")
	zip.close()
	return {"success": errors.is_empty(), "path": output_path, "asset_count": records.size(), "errors": errors}


func inspect_pack(path: String) -> Dictionary:
	if not FileAccess.file_exists(_absolute(path)): return {"success": false, "errors": ["Asset pack was not found."]}
	var reader := ZIPReader.new()
	if reader.open(_absolute(path)) != OK: return {"success": false, "errors": ["Asset pack could not be opened."]}
	var raw := reader.read_file("asset_pack.json")
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	var files := reader.get_files()
	reader.close()
	if not parsed is Dictionary or str((parsed as Dictionary).get("format", "")) != FORMAT: return {"success": false, "errors": ["Asset pack has no valid manifest."]}
	return {"success": true, "manifest": parsed, "files": files}


func extract_pack(path: String, destination: String) -> Dictionary:
	var inspected := inspect_pack(path)
	if not bool(inspected.get("success", false)): return inspected
	var root := _absolute(destination)
	if DirAccess.make_dir_recursive_absolute(root) != OK: return {"success": false, "errors": ["Could not create asset-pack destination."]}
	var reader := ZIPReader.new()
	if reader.open(_absolute(path)) != OK: return {"success": false, "errors": ["Asset pack could not be opened."]}
	var extracted: Array = []
	var errors: Array = []
	for entry in reader.get_files():
		var safe := str(entry).replace("\\", "/")
		if safe.contains("..") or safe.begins_with("/") or safe.begins_with("~"):
			errors.append("Rejected unsafe pack entry: " + safe)
			continue
		if safe.ends_with("/"):
			if DirAccess.make_dir_recursive_absolute(root.path_join(safe)) != OK: errors.append("Could not create folder: " + safe)
			continue
		var target := root.path_join(safe)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			errors.append("Could not create destination for: " + safe)
			continue
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			errors.append("Could not extract: " + safe)
			continue
		file.store_buffer(reader.read_file(safe))
		file.close()
		extracted.append(target)
	reader.close()
	return {"success": errors.is_empty(), "files": extracted, "manifest": inspected.get("manifest", {}), "errors": errors}


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
