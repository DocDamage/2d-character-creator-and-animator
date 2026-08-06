# Portable resource carrier used by exported character scenes.
extends Resource

@export var package_data: Dictionary = {}
@export var source_project_id: String = ""
@export var package_version: String = "1.0.0"


func configure(package: Dictionary) -> void:
	package_data = package.duplicate(true)
	var content: Dictionary = package_data.get("content", {})
	source_project_id = str(content.get("project_id", ""))
	package_version = str(package_data.get("format_version", "1.0.0"))


func get_content() -> Dictionary:
	return (package_data.get("content", {}) as Dictionary).duplicate(true)
