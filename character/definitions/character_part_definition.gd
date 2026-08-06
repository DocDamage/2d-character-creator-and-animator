# CharacterPartDefinition -- Serializable modular part definition and compatibility metadata.
class_name CharacterPartDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var part_id: String = ""
var display_name: String = ""
var slot_id: String = ""
var asset_id: String = ""
var supported_body_type_ids: PackedStringArray = []
var tags: PackedStringArray = []
var required_tags: PackedStringArray = []
var excluded_tags: PackedStringArray = []
var conflict_part_ids: PackedStringArray = []
var palette_channels: Dictionary = {}
var attachment_map: Dictionary = {}
var metadata: Dictionary = {}


func _init(p_id: String = "", p_name: String = "", p_slot_id: String = "") -> void:
	part_id = p_id.strip_edges()
	display_name = p_name.strip_edges()
	slot_id = p_slot_id.strip_edges()


func supports_body_type(body_type_id: String) -> bool:
	return supported_body_type_ids.is_empty() or body_type_id in supported_body_type_ids


func conflicts_with(other) -> bool:
	if other == null or other.part_id == part_id:
		return false
	if other.part_id in conflict_part_ids or part_id in other.conflict_part_ids:
		return true
	for tag in other.tags:
		if tag in excluded_tags:
			return true
	for tag in tags:
		if tag in other.excluded_tags:
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION, "part_id": part_id, "display_name": display_name,
		"slot_id": slot_id, "asset_id": asset_id, "supported_body_type_ids": Array(supported_body_type_ids),
		"tags": Array(tags), "required_tags": Array(required_tags), "excluded_tags": Array(excluded_tags),
		"conflict_part_ids": Array(conflict_part_ids), "palette_channels": palette_channels.duplicate(true),
		"attachment_map": attachment_map.duplicate(true), "metadata": metadata.duplicate(true),
	}


func from_dict(data: Dictionary) -> CharacterPartDefinition:
	part_id = str(data.get("part_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	slot_id = str(data.get("slot_id", "")).strip_edges()
	asset_id = str(data.get("asset_id", "")).strip_edges()
	supported_body_type_ids = PackedStringArray(data.get("supported_body_type_ids", []))
	tags = PackedStringArray(data.get("tags", []))
	required_tags = PackedStringArray(data.get("required_tags", []))
	excluded_tags = PackedStringArray(data.get("excluded_tags", []))
	conflict_part_ids = PackedStringArray(data.get("conflict_part_ids", []))
	palette_channels = (data.get("palette_channels", {}) as Dictionary).duplicate(true)
	attachment_map = (data.get("attachment_map", {}) as Dictionary).duplicate(true)
	metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
	return self


func validate() -> Array:
	var errors: Array = []
	if part_id.is_empty(): errors.append("Character part requires part_id.")
	if display_name.is_empty(): errors.append("Character part '%s' requires display_name." % part_id)
	if slot_id.is_empty(): errors.append("Character part '%s' requires slot_id." % part_id)
	if asset_id.is_empty(): errors.append("Character part '%s' requires asset_id." % part_id)
	return errors
