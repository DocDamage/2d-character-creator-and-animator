# InteractionFamilyRegistry -- Named movement families shared by weapon definitions.
class_name InteractionFamilyRegistry
extends RefCounted

var _families: Dictionary = {}


func register_family(family_id: String, display_name: String, capabilities: PackedStringArray = []) -> bool:
	if family_id.is_empty() or display_name.is_empty() or _families.has(family_id):
		return false
	_families[family_id] = {
		"family_id": family_id,
		"display_name": display_name,
		"capabilities": Array(capabilities)
	}
	return true


func get_family(family_id: String) -> Dictionary:
	return (_families.get(family_id, {}) as Dictionary).duplicate(true)


func supports(family_id: String, capability: String) -> bool:
	var family := get_family(family_id)
	return capability in family.get("capabilities", [])


func list_families() -> Array:
	var result: Array = []
	for family in _families.values():
		result.append((family as Dictionary).duplicate(true))
	result.sort_custom(func(a, b): return str(a.get("display_name", "")) < str(b.get("display_name", "")))
	return result


func to_dict() -> Dictionary:
	return {"families": _families.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_families = (data.get("families", {}) as Dictionary).duplicate(true)
