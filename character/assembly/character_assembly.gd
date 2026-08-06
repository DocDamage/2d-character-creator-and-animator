# CharacterAssembly -- Validated, serializable composition of registered modular character parts.
class_name CharacterAssembly
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

var character_id: String = ""
var display_name: String = ""
var body_type_id: String = ""
var equipped_by_slot: Dictionary = {}
var equipped_weapon_id: String = ""
var palette_values: Dictionary = {}
var attachment_maps: Dictionary = {}
var metadata: Dictionary = {}

var _part_registry = null
var _slot_registry = null
var _body_types: Dictionary = {}


func _init(p_id: String = "", p_name: String = "") -> void:
	character_id = p_id.strip_edges()
	display_name = p_name.strip_edges()


func configure(part_registry, slot_registry, body_types: Array = []) -> void:
	_part_registry = part_registry
	_slot_registry = slot_registry
	_body_types.clear()
	for body_type in body_types:
		if body_type != null and not body_type.body_type_id.is_empty():
			_body_types[body_type.body_type_id] = body_type


func set_body_type(next_body_type_id: String) -> Dictionary:
	if not _body_types.has(next_body_type_id):
		return _failure("UNKNOWN_BODY_TYPE", "Choose a registered body type.", {"body_type_id": next_body_type_id})
	for part in get_equipped_parts():
		if not part.supports_body_type(next_body_type_id):
			return _failure("BODY_TYPE_INCOMPATIBLE", "Unequip '%s' or choose a compatible body type." % part.display_name, {"part_id": part.part_id, "body_type_id": next_body_type_id})
	body_type_id = next_body_type_id
	return {"success": true, "errors": [], "repair_actions": []}


func equip_part(part_id: String) -> Dictionary:
	var part = _part_registry.get_part(part_id) if _part_registry != null else null
	if part == null:
		return _failure("UNKNOWN_PART", "Choose a registered character part.", {"part_id": part_id})
	var slot = _slot_registry.get_slot(part.slot_id) if _slot_registry != null else null
	if slot == null:
		return _failure("UNKNOWN_SLOT", "Register the part's slot before equipping it.", {"slot_id": part.slot_id})
	if not slot.accepts(part):
		return _failure("SLOT_REJECTS_PART", "This slot does not accept the selected part.", {"part_id": part_id, "slot_id": part.slot_id})
	if not part.supports_body_type(body_type_id):
		return _failure("BODY_TYPE_INCOMPATIBLE", "Choose a part that supports the current body type.", {"part_id": part_id, "body_type_id": body_type_id})
	var previous := equipped_by_slot.duplicate(true)
	var selected: Array = equipped_by_slot.get(part.slot_id, []).duplicate()
	if slot.allow_multiple:
		if part_id not in selected: selected.append(part_id)
	else:
		selected = [part_id]
	equipped_by_slot[part.slot_id] = selected
	var report := explain_part(part_id)
	if not bool(report.get("success", false)):
		equipped_by_slot = previous
		return report
	return {"success": true, "errors": [], "repair_actions": [], "equipped_part_id": part_id}


func unequip_part(part_id: String) -> bool:
	for slot_id in equipped_by_slot.keys():
		var selected: Array = equipped_by_slot[slot_id]
		if part_id in selected:
			selected.erase(part_id)
			if selected.is_empty(): equipped_by_slot.erase(slot_id)
			else: equipped_by_slot[slot_id] = selected
			return true
	return false


func get_equipped_part_ids() -> Array:
	var result: Array = []
	for selected in equipped_by_slot.values():
		for part_id in selected:
			if str(part_id) not in result: result.append(str(part_id))
	result.sort()
	return result


func get_equipped_parts() -> Array:
	var result: Array = []
	if _part_registry == null: return result
	for part_id in get_equipped_part_ids():
		var part = _part_registry.get_part(part_id)
		if part != null: result.append(part)
	return result


func explain_part(part_id: String) -> Dictionary:
	var part = _part_registry.get_part(part_id) if _part_registry != null else null
	if part == null: return _failure("UNKNOWN_PART", "Choose a registered character part.", {"part_id": part_id})
	var reasons: Array = []
	if not part.supports_body_type(body_type_id): reasons.append("This part does not support body type '%s'." % body_type_id)
	var tags := _equipped_tags()
	for tag in part.required_tags:
		if tag not in tags: reasons.append("Equip a part tagged '%s' first." % tag)
	for other in get_equipped_parts():
		if part.conflicts_with(other): reasons.append("Remove conflicting part '%s'." % other.display_name)
	return {"success": reasons.is_empty(), "errors": reasons, "repair_actions": _repairs_for_messages(reasons), "part_id": part_id}


func validate() -> Dictionary:
	var errors: Array = []
	if character_id.is_empty(): errors.append("Character assembly requires character_id.")
	if display_name.is_empty(): errors.append("Character assembly '%s' requires display_name." % character_id)
	var body = _body_types.get(body_type_id, null)
	if body == null: errors.append("Choose a registered body type.")
	var parts := get_equipped_parts()
	for part_id in get_equipped_part_ids():
		if _part_registry == null or _part_registry.get_part(part_id) == null:
			errors.append("Equipped part '%s' is not registered." % part_id)
	for part in parts:
		if not part.supports_body_type(body_type_id): errors.append("Part '%s' does not support body type '%s'." % [part.part_id, body_type_id])
		var slot = _slot_registry.get_slot(part.slot_id) if _slot_registry != null else null
		if slot == null: errors.append("Part '%s' references an unregistered slot." % part.part_id)
		elif not slot.allow_multiple and (equipped_by_slot.get(part.slot_id, []) as Array).size() > 1: errors.append("Slot '%s' allows only one part." % part.slot_id)
		for tag in part.required_tags:
			if tag not in _equipped_tags(): errors.append("Part '%s' requires tag '%s'." % [part.part_id, tag])
	for first_index in parts.size():
		for second_index in range(first_index + 1, parts.size()):
			if parts[first_index].conflicts_with(parts[second_index]): errors.append("Parts '%s' and '%s' conflict." % [parts[first_index].part_id, parts[second_index].part_id])
	if body != null:
		for slot_id in body.required_slot_ids:
			if not equipped_by_slot.has(slot_id) or (equipped_by_slot[slot_id] as Array).is_empty(): errors.append("Body type '%s' requires slot '%s'." % [body_type_id, slot_id])
	if _slot_registry != null:
		for slot in _slot_registry.list_slots():
			if slot.required and (not equipped_by_slot.has(slot.slot_id) or (equipped_by_slot[slot.slot_id] as Array).is_empty()): errors.append("Required slot '%s' is empty." % slot.slot_id)
	return {"success": errors.is_empty(), "errors": errors, "repair_actions": _repairs_for_messages(errors)}


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "character_id": character_id, "display_name": display_name, "body_type_id": body_type_id, "equipped_by_slot": equipped_by_slot.duplicate(true), "equipped_weapon_id": equipped_weapon_id, "palette_values": palette_values.duplicate(true), "attachment_maps": attachment_maps.duplicate(true), "metadata": metadata.duplicate(true)}


func from_dict(data: Dictionary) -> CharacterAssembly:
	character_id = str(data.get("character_id", "")).strip_edges()
	display_name = str(data.get("display_name", "")).strip_edges()
	body_type_id = str(data.get("body_type_id", "")).strip_edges()
	equipped_by_slot = (data.get("equipped_by_slot", {}) as Dictionary).duplicate(true)
	equipped_weapon_id = str(data.get("equipped_weapon_id", "")).strip_edges()
	palette_values = (data.get("palette_values", {}) as Dictionary).duplicate(true)
	attachment_maps = (data.get("attachment_maps", {}) as Dictionary).duplicate(true)
	metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
	return self


func _equipped_tags() -> Array:
	var tags: Array = []
	for part in get_equipped_parts():
		for tag in part.tags:
			if tag not in tags: tags.append(tag)
	return tags


func _failure(code: String, message: String, context: Dictionary) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": [{"code": code, "message": message, "context": context.duplicate(true)}]}


func _repairs_for_messages(messages: Array) -> Array:
	var repairs: Array = []
	for message in messages:
		repairs.append({"action": "resolve_assembly", "message": str(message)})
	return repairs
