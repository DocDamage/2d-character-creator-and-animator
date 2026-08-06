# CharacterSlotDefinition -- Authoring schema for a named character equipment slot.
class_name CharacterSlotDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var slot_id: String = ""
var display_name: String = ""
var required: bool = false
var allow_multiple: bool = false
var allowed_part_tags: PackedStringArray = []
var default_part_id: String = ""


func _init(p_id: String = "", p_name: String = "") -> void:
	slot_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func accepts(part) -> bool:
	if part == null or part.slot_id != slot_id:
		return false
	if allowed_part_tags.is_empty():
		return true
	for tag in part.tags:
		if tag in allowed_part_tags:
			return true
	return false


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "slot_id": slot_id, "display_name": display_name, "required": required, "allow_multiple": allow_multiple, "allowed_part_tags": Array(allowed_part_tags), "default_part_id": default_part_id}


func from_dict(data: Dictionary) -> CharacterSlotDefinition:
	slot_id = str(data.get("slot_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	required = bool(data.get("required", false))
	allow_multiple = bool(data.get("allow_multiple", false))
	allowed_part_tags = PackedStringArray(data.get("allowed_part_tags", []))
	default_part_id = str(data.get("default_part_id", "")).strip_edges()
	return self


func validate() -> Array:
	var errors: Array = []
	if slot_id.is_empty():
		errors.append("Character slot requires slot_id.")
	if display_name.is_empty():
		errors.append("Character slot '%s' requires display_name." % slot_id)
	return errors
