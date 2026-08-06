# ChrprojImporter -- Converts authoring .chrproj JSON into consumer-safe runtime data.
class_name ChrprojImporter
extends RefCounted

const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")
const CharacterRuntimeDataScript = preload("res://runtime_plugin/player/character_runtime_data.gd")


func import_file(source_path: String, output_path: String, metadata: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return {"success": false, "errors": ["source .chrproj was not found"]}
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"success": false, "errors": ["source .chrproj cannot be read"]}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.get_data() is Dictionary:
		return {"success": false, "errors": ["source .chrproj is not valid JSON"]}
	return import_data(json.get_data() as Dictionary, output_path, metadata)


func import_data(project_data: Dictionary, output_path: String, metadata: Dictionary = {}) -> Dictionary:
	var package := RuntimePackageScript.create(project_data, metadata)
	var validation := RuntimePackageScript.validate(package)
	if not validation.is_empty():
		return {"success": false, "errors": validation}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create import destination"]}
	var resource := CharacterRuntimeDataScript.new()
	resource.configure(package)
	var error := ResourceSaver.save(resource, output_path)
	return {"success": error == OK, "path": output_path, "errors": [] if error == OK else ["cannot save imported runtime resource"]}
