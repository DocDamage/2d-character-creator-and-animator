# CharacterProjectFactory -- Creates valid, editable character-project documents.
class_name CharacterProjectFactory
extends RefCounted

const ProjectSchemaScript = preload("res://core/documents/project_schema.gd")
const BodyScript = preload("res://character/definitions/character_body_type_definition.gd")
const SlotScript = preload("res://character/definitions/character_slot_definition.gd")

const DEFAULT_BODY_TYPE_ID := "humanoid"
const DEFAULT_CHARACTER_ID := "character_main"
const DEFAULT_SLOTS := [
	["body", "Body / Base"],
	["legs", "Legs"],
	["outfit", "Outfit / Torso"],
	["head", "Head"],
	["face", "Face / Eyes"],
	["hair", "Hair"],
	["hands", "Hands"],
	["accessory", "Accessory"],
]

const SLOT_TEMPLATES := [
	{
		"id": "blank", "name": "Layered Humanoid", "description": "A flexible eight-slot character stack for imported artwork.",
		"slots": DEFAULT_SLOTS, "canvas": {"width": 512, "height": 512, "pixel_scale": 1.0},
	},
	{
		"id": "portrait", "name": "Portrait / Avatar", "description": "A compact head-and-shoulders stack for imported portraits.",
		"slots": [["background", "Background"], ["body", "Shoulders / Base"], ["head", "Head"], ["face", "Face / Features"], ["hair", "Hair"], ["accessory", "Accessory"]],
		"canvas": {"width": 512, "height": 512, "pixel_scale": 1.0},
	},
	{
		"id": "side_scroller", "name": "Side-Scroller Hero", "description": "A production-friendly stack for side-view sprites.",
		"slots": [["shadow", "Shadow"], ["body", "Body / Base"], ["legs", "Legs"], ["outfit", "Outfit"], ["head", "Head"], ["face", "Face"], ["hair", "Hair"], ["hands", "Hands / Weapon"], ["accessory", "Accessory / FX"]],
		"canvas": {"width": 384, "height": 384, "pixel_scale": 1.0},
	},
]


static func create_manifest(project_name: String, template_id: String = "blank") -> Dictionary:
	var clean_name := project_name.strip_edges()
	if clean_name.is_empty(): clean_name = "Untitled Character"
	var selected_template := get_slot_template(template_id)
	if selected_template.is_empty(): selected_template = get_slot_template("blank")
	var manifest := ProjectSchemaScript.create_default_manifest(clean_name)
	var body = create_default_body_type()
	var slots := create_slots_for_template(str(selected_template.get("id", "blank")))
	var slot_data := {}
	var slot_order: Array[String] = []
	for slot in slots:
		slot_data[slot.slot_id] = slot.to_dict()
		slot_order.append(slot.slot_id)
	manifest.objects.body_types[body.body_type_id] = body.to_dict()
	manifest.objects.characters[DEFAULT_CHARACTER_ID] = _empty_creator_data(clean_name)
	manifest.settings.default_body_type = body.body_type_id
	manifest.metadata["template_id"] = str(selected_template.get("id", "blank"))
	manifest.metadata["character_authoring"] = {
		"active_character_id": DEFAULT_CHARACTER_ID,
		"slot_order": slot_order,
		"slots": slot_data,
		"parts": {},
		"canvas": selected_template.get("canvas", get_default_canvas_settings()).duplicate(true),
		"workflow": {"new_project": true, "completed": false, "current_step": 0, "deferred": false},
	}
	return manifest


static func save_new_project(path: String, project_name: String, template_id: String = "blank") -> bool:
	if path.strip_edges().is_empty(): return false
	if FileAccess.file_exists(path):
		var existing := SerializationService.load_project(path)
		if not existing.is_empty(): return false
		if not _is_legacy_generated_file(path): return false
	return SerializationService.save_project(create_manifest(project_name, template_id), path)


static func create_default_slots() -> Array:
	return create_slots_for_template("blank")


static func create_slots_for_template(template_id: String) -> Array:
	var slots: Array = []
	var template := get_slot_template(template_id)
	var entries: Array = template.get("slots", DEFAULT_SLOTS)
	for entry in entries:
		var slot = SlotScript.new(entry[0], entry[1])
		slot.required = false
		slots.append(slot)
	return slots


static func get_slot_template_options() -> Array:
	var options: Array = []
	for template in SLOT_TEMPLATES:
		options.append({"id": str(template.get("id", "")), "name": str(template.get("name", "")), "description": str(template.get("description", "")), "slot_count": (template.get("slots", []) as Array).size(), "canvas": (template.get("canvas", {}) as Dictionary).duplicate(true)})
	return options


static func get_slot_template(template_id: String) -> Dictionary:
	for template in SLOT_TEMPLATES:
		if str(template.get("id", "")) == template_id:
			return (template as Dictionary).duplicate(true)
	return {}


static func get_default_canvas_settings() -> Dictionary:
	return {"width": 512, "height": 512, "pixel_scale": 1.0}


static func create_default_body_type():
	var body = BodyScript.new(DEFAULT_BODY_TYPE_ID, "Layered 2D Character")
	body.metadata = {"authoring_mode": "image_layers"}
	return body


static func _empty_creator_data(display_name: String) -> Dictionary:
	return {
		"assembly": {
			"schema_version": "1.0.0",
			"character_id": DEFAULT_CHARACTER_ID,
			"display_name": display_name,
			"body_type_id": DEFAULT_BODY_TYPE_ID,
			"equipped_by_slot": {},
			"equipped_weapon_id": "",
			"palette_values": {},
			"attachment_maps": {},
			"metadata": {"authoring_mode": "imported_image_layers"},
		},
		"outfits": {},
		"appearance_sets": {},
		"presets": {},
		"locked_part_ids": [],
		"locked_palette_channels": [],
	}


static func _is_legacy_generated_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed is Dictionary and parsed.has("name") and parsed.has("template") and parsed.has("version")
