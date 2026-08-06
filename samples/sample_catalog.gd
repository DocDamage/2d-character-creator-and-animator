# SampleCatalog -- Validated representative project fixtures shipped with the authoring application.
class_name SampleCatalog
extends RefCounted

const ProjectSchemaScript = preload("res://core/documents/project_schema.gd")

const SAMPLES := [
	{"sample_id": "humanoid", "path": "res://samples/humanoid_modular.chrproj", "scope": "modular humanoid character"},
	{"sample_id": "pixel", "path": "res://samples/pixel_character.chrproj", "scope": "pixel-safe character"},
	{"sample_id": "deformable", "path": "res://samples/deformable_mesh.chrproj", "scope": "weighted deformable mesh"},
	{"sample_id": "crowd", "path": "res://samples/hundred_characters.chrproj", "scope": "100-character stress fixture"},
	{"sample_id": "weapons", "path": "res://samples/twenty_weapons.chrproj", "scope": "20-weapon posing fixture"},
	{"sample_id": "gameplay", "path": "res://samples/animation_gameplay.chrproj", "scope": "animation and gameplay metadata"},
]


func list_samples() -> Array: return SAMPLES.duplicate(true)


func validate() -> Dictionary:
	var missing: Array = []
	var invalid: Array = []
	for sample in SAMPLES:
		var path := str((sample as Dictionary).get("path", ""))
		if not FileAccess.file_exists(path): missing.append(path); continue
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		var ok := file != null and json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary and ProjectSchemaScript.is_valid(json.get_data() as Dictionary)
		if file != null: file.close()
		if not ok: invalid.append(path)
	return {"valid": missing.is_empty() and invalid.is_empty(), "missing": missing, "invalid": invalid, "samples": SAMPLES.duplicate(true)}
