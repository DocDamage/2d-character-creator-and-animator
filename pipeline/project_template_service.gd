# ProjectTemplateService -- Reusable, versioned starting points for character projects.
class_name ProjectTemplateService
extends RefCounted

const ProjectSchemaScript = preload("res://core/documents/project_schema.gd")
const ProductionDataScript = preload("res://production/production_project_data.gd")


static func list_templates() -> Array:
	return [
		{"template_id": "blank", "display_name": "Blank Character", "description": "A minimal project with no assumptions."},
		{"template_id": "combat_2d", "display_name": "2D Combat Character", "description": "Combat metadata, runtime profiles, and motion-library categories."},
		{"template_id": "dialogue", "display_name": "Dialogue Character", "description": "Expression, viseme, and approval-presentation defaults."},
		{"template_id": "pixel_fighter", "display_name": "Pixel Fighter", "description": "Pixel-safe canvas and hard-switch facing defaults."},
	]


static func create(template_id: String, project_name: String, project_id: String = "") -> Dictionary:
	var manifest := ProjectSchemaScript.create_default_manifest(project_name.strip_edges() if not project_name.strip_edges().is_empty() else "Untitled Project", project_id)
	var production := ProductionDataScript.defaults()
	production["pipeline"]["template_id"] = template_id
	match template_id:
		"combat_2d":
			manifest["settings"]["default_fps"] = 30
			production["presentation"]["pose_boards"]["combat"] = {"board_id": "combat", "display_name": "Combat Approval Board", "pose_ids": []}
		"dialogue":
			production["presentation"]["expressions"]["neutral"] = {"expression_id": "neutral", "display_name": "Neutral", "viseme": "rest"}
		"pixel_fighter":
			manifest["settings"]["pixel_mode"] = true
			manifest["settings"]["default_fps"] = 12
		"blank": pass
		_: return {"success": false, "errors": ["Unknown project template: " + template_id]}
	manifest = ProductionDataScript.apply_to_manifest(manifest, production)
	return {"success": true, "manifest": manifest, "template_id": template_id}


static func write(template_id: String, project_name: String, output_path: String, project_id: String = "") -> Dictionary:
	var created := create(template_id, project_name, project_id)
	if not bool(created.get("success", false)): return created
	var absolute := ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") or output_path.begins_with("user://") else output_path
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return {"success": false, "errors": ["Could not create template-project directory."]}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: return {"success": false, "errors": ["Could not save template project."]}
	file.store_string(JSON.stringify(created.get("manifest", {}) as Dictionary, "\t", true, false))
	file.close()
	return {"success": true, "path": output_path, "template_id": template_id}
