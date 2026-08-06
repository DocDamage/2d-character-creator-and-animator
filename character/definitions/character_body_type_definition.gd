# CharacterBodyTypeDefinition -- Serializable body-shape requirements for character assembly.
class_name CharacterBodyTypeDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var body_type_id: String = ""
var display_name: String = ""
var tags: PackedStringArray = []
var required_slot_ids: PackedStringArray = []
var supported_weapon_tags: PackedStringArray = []
var metadata: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	body_type_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func supports_weapon_tags(weapon_tags: Array) -> bool:
	if supported_weapon_tags.is_empty() or weapon_tags.is_empty():
		return true
	for tag in weapon_tags:
		if str(tag) in supported_weapon_tags:
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"body_type_id": body_type_id,
		"display_name": display_name,
		"tags": Array(tags),
		"required_slot_ids": Array(required_slot_ids),
		"supported_weapon_tags": Array(supported_weapon_tags),
		"metadata": metadata.duplicate(true),
	}


func from_dict(data: Dictionary) -> CharacterBodyTypeDefinition:
	body_type_id = str(data.get("body_type_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	tags = PackedStringArray(data.get("tags", []))
	required_slot_ids = PackedStringArray(data.get("required_slot_ids", []))
	supported_weapon_tags = PackedStringArray(data.get("supported_weapon_tags", []))
	metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if body_type_id.is_empty():
		errors.append("Character body type requires body_type_id.")
	if display_name.is_empty():
		errors.append("Character body type '%s' requires display_name." % body_type_id)
	return errors
