# RuntimePackage -- Versioned, portable data envelope consumed by exporters and the player.
class_name RuntimePackage
extends RefCounted

const FORMAT_NAME := "chr_runtime_package"
const FORMAT_VERSION := "1.0.0"


static func create(project_data: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	return {
		"format": FORMAT_NAME,
		"format_version": FORMAT_VERSION,
		"metadata": metadata.duplicate(true),
		"content": project_data.duplicate(true),
	}


static func validate(package: Dictionary) -> Array:
	var errors: Array = []
	if str(package.get("format", "")) != FORMAT_NAME:
		errors.append("unexpected runtime package format")
	if str(package.get("format_version", "")).is_empty():
		errors.append("format_version is required")
	if not package.get("content", {}) is Dictionary:
		errors.append("content must be a dictionary")
	return errors


static func save(package: Dictionary, file_path: String) -> Dictionary:
	var errors := validate(package)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	var absolute := ProjectSettings.globalize_path(file_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create output directory"]}
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["cannot write runtime package"]}
	file.store_string(JSON.stringify(package, "\t", true, false))
	file.close()
	return {"success": true, "path": file_path, "hash": JSON.stringify(package, "", true, false).sha256_text()}


static func load(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"success": false, "errors": ["runtime package file was not found"]}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "errors": ["runtime package cannot be read"]}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.get_data() is Dictionary:
		return {"success": false, "errors": ["runtime package is not valid JSON"]}
	var package := json.get_data() as Dictionary
	var errors := validate(package)
	return {"success": errors.is_empty(), "package": package, "errors": errors}
