# CharacterPartRegistry -- Searchable collection of compatible character-part definitions.
class_name CharacterPartRegistry
extends RefCounted

var _parts: Dictionary = {}


func register_part(part) -> bool:
	if part == null or not part.validate().is_empty() or _parts.has(part.part_id):
		return false
	_parts[part.part_id] = part
	return true


func get_part(part_id: String):
	return _parts.get(part_id, null)


func list_parts(filters: Dictionary = {}) -> Array:
	var body_type_id := str(filters.get("body_type_id", ""))
	var slot_id := str(filters.get("slot_id", ""))
	var query := str(filters.get("query", "")).to_lower().strip_edges()
	var required_tags: Array = filters.get("required_tags", [])
	var result: Array = []
	for part in _parts.values():
		if not slot_id.is_empty() and part.slot_id != slot_id: continue
		if not body_type_id.is_empty() and not part.supports_body_type(body_type_id): continue
		if not query.is_empty() and query not in part.display_name.to_lower() and query not in part.part_id.to_lower(): continue
		var matches := true
		for tag in required_tags:
			if str(tag) not in part.tags:
				matches = false
				break
		if matches: result.append(part)
	result.sort_custom(func(a, b): return a.part_id < b.part_id)
	return result


func validate(slot_registry = null) -> Array:
	var errors: Array = []
	for part in _parts.values():
		errors.append_array(part.validate())
		if slot_registry != null and not slot_registry.has_slot(part.slot_id):
			errors.append("Character part '%s' references unknown slot '%s'." % [part.part_id, part.slot_id])
	return errors
