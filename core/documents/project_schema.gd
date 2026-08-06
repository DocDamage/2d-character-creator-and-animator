# ProjectSchema — Defines schema, validation rules, and default factory for project manifests (.chrproj)
# Part of core/documents/ module.
class_name ProjectSchema

const SCHEMA_VERSION := "1.0.0"

# Required top-level keys and their expected TYPE_* values
const REQUIRED_ROOT_FIELDS: Dictionary = {
	"schema_version": TYPE_STRING,
	"project_id": TYPE_STRING,
	"project_name": TYPE_STRING,
	"created_at": [TYPE_INT, TYPE_FLOAT],
	"modified_at": [TYPE_INT, TYPE_FLOAT],
	"objects": TYPE_DICTIONARY,
	"settings": TYPE_DICTIONARY,
	"metadata": TYPE_DICTIONARY,
}

# Required sub-dictionaries inside the 'objects' container
const REQUIRED_OBJECT_CATEGORIES: PackedStringArray = [
	"characters",
	"rigs",
	"animations",
	"weapons",
	"assets"
]

# Additional standard object categories
const OPTIONAL_OBJECT_CATEGORIES: PackedStringArray = [
	"palettes",
	"body_types",
	"export_profiles",
	"gameplay_metadata"
]

static func create_default_manifest(project_name: String = "Untitled Project", project_id: String = "") -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var final_id := project_id
	if final_id.is_empty():
		if Engine.has_singleton("IDService") or IDService:
			final_id = IDService.generate_uuid_v4()
		else:
			final_id = "00000000-0000-4000-8000-000000000000"

	return {
		"schema_version": SCHEMA_VERSION,
		"project_id": final_id,
		"project_name": project_name,
		"created_at": now,
		"modified_at": now,
		"objects": {
			"characters": {},
			"rigs": {},
			"animations": {},
			"weapons": {},
			"assets": {},
			"palettes": {},
			"body_types": {},
			"export_profiles": {},
			"gameplay_metadata": {}
		},
		"settings": {
			"default_facing_directions": 8,
			"default_fps": 30,
			"pixel_mode": false,
			"default_body_type": "humanoid_male"
		},
		"metadata": {
			"author": "",
			"description": "",
			"generator": "Modular 2D Character Creator and Animation Studio"
		}
	}


static func validate_manifest(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []

	if data.is_empty():
		errors.append("Manifest is empty")
		return errors

	# Check root fields
	for key in REQUIRED_ROOT_FIELDS.keys():
		if not data.has(key):
			errors.append("Missing root field: '%s'" % key)
			continue

		var expected_type = REQUIRED_ROOT_FIELDS[key]
		var val = data[key]
		if expected_type is Array:
			var matched := false
			for t in expected_type:
				if typeof(val) == t:
					matched = true
					break
			if not matched:
				errors.append("Invalid type for field '%s': expected int/float, got %s" % [key, typeof(val)])
		elif typeof(val) != expected_type:
			errors.append("Invalid type for field '%s': expected %s, got %s" % [key, expected_type, typeof(val)])

	if not errors.is_empty():
		return errors

	# Validate project_id is non-empty
	var id_str: String = data.get("project_id", "")
	if id_str.strip_edges().is_empty():
		errors.append("project_id must not be empty")

	# Validate schema_version is non-empty
	var ver_str: String = data.get("schema_version", "")
	if ver_str.strip_edges().is_empty():
		errors.append("schema_version must not be empty")

	# Validate objects container
	var objects: Dictionary = data.get("objects", {})
	for cat in REQUIRED_OBJECT_CATEGORIES:
		if not objects.has(cat):
			errors.append("Missing required object category: '%s'" % cat)
		elif typeof(objects[cat]) != TYPE_DICTIONARY:
			errors.append("Object category '%s' must be a dictionary" % cat)

	# Validate settings
	var settings: Dictionary = data.get("settings", {})
	if settings.has("default_facing_directions"):
		var dirs = settings["default_facing_directions"]
		if (typeof(dirs) != TYPE_INT and typeof(dirs) != TYPE_FLOAT) or int(dirs) <= 0:
			errors.append("default_facing_directions must be a positive integer")
	if settings.has("default_fps"):
		var fps = settings["default_fps"]
		if (typeof(fps) != TYPE_INT and typeof(fps) != TYPE_FLOAT) or int(fps) <= 0:
			errors.append("default_fps must be a positive integer")
	if settings.has("pixel_mode"):
		if typeof(settings["pixel_mode"]) != TYPE_BOOL:
			errors.append("pixel_mode must be a boolean")

	return errors


static func is_valid(data: Dictionary) -> bool:
	return validate_manifest(data).is_empty()


static func get_unknown_fields(data: Dictionary) -> Dictionary:
	var unknown_root: Array[String] = []
	var unknown_categories: Array[String] = []

	for key in data.keys():
		if not REQUIRED_ROOT_FIELDS.has(key) and key not in ["cloned_from", "_serializer_version"]:
			unknown_root.append(key)

	if data.has("objects") and typeof(data["objects"]) == TYPE_DICTIONARY:
		var objects: Dictionary = data["objects"]
		for cat in objects.keys():
			if cat not in REQUIRED_OBJECT_CATEGORIES and cat not in OPTIONAL_OBJECT_CATEGORIES:
				unknown_categories.append(cat)

	return {
		"unknown_root": unknown_root,
		"unknown_categories": unknown_categories
	}
