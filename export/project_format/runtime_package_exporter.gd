# RuntimePackageExporter -- Builds and writes deterministic, self-describing runtime packages.
class_name RuntimePackageExporter
extends RefCounted

const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")


func export_project(project_data: Dictionary, output_path: String, metadata: Dictionary = {}) -> Dictionary:
	var package := RuntimePackageScript.create(project_data, metadata)
	return RuntimePackageScript.save(package, output_path)


func build_project_content(project_data: Dictionary) -> Dictionary:
	var content := project_data.duplicate(true)
	content["exported_at"] = Time.get_datetime_string_from_system(true)
	return content
