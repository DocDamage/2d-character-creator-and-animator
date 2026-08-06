# Consumer-side .chrproj importer with no authoring-project code dependency.
extends RefCounted

const RuntimePackageScript = preload("res://addons/modular_character_runtime/runtime/runtime_package.gd")
const CharacterRuntimeDataScript = preload("res://addons/modular_character_runtime/runtime/character_runtime_data.gd")


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
	var report := _build_import_report(project_data)
	var package_metadata := metadata.duplicate(true)
	package_metadata["import_report"] = report
	var package := RuntimePackageScript.create(project_data, package_metadata)
	var validation := RuntimePackageScript.validate(package)
	if not validation.is_empty():
		return {"success": false, "errors": validation}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir()) != OK:
		return {"success": false, "errors": ["cannot create import destination"]}
	var resource := CharacterRuntimeDataScript.new()
	resource.configure(package)
	var error := ResourceSaver.save(resource, output_path)
	return {"success": error == OK, "path": output_path, "report": report, "errors": [] if error == OK else ["cannot save imported runtime resource"]}


func _build_import_report(project_data: Dictionary) -> Dictionary:
	var warnings: Array = []
	for required in ["project_id", "state_machine"]:
		if not project_data.has(required): warnings.append("missing recommended runtime section: " + required)
	return {"project_id": str(project_data.get("project_id", "")), "warnings": warnings, "has_rig": project_data.has("rig") or project_data.has("skeleton"), "has_rules": project_data.has("rule_graph"), "has_facing": project_data.has("facing_grid") or project_data.has("facing_grids")}
