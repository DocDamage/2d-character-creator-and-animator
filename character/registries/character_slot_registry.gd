# CharacterSlotRegistry -- Validated collection of character slot schemas.
class_name CharacterSlotRegistry
extends RefCounted

var _slots: Dictionary = {}


func register_slot(slot) -> bool:
	if slot == null or not slot.validate().is_empty() or _slots.has(slot.slot_id):
		return false
	_slots[slot.slot_id] = slot
	return true


func get_slot(slot_id: String):
	return _slots.get(slot_id, null)


func list_slots() -> Array:
	var result: Array = _slots.values()
	result.sort_custom(func(a, b): return a.slot_id < b.slot_id)
	return result


func has_slot(slot_id: String) -> bool:
	return _slots.has(slot_id)


func validate() -> Array:
	var errors: Array = []
	for slot in _slots.values():
		errors.append_array(slot.validate())
	return errors
