# CharacterCreatorModel -- User-facing character assembly workflows with deterministic reversible edits.
class_name CharacterCreatorModel
extends Node

const AssemblyScript = preload("res://character/assembly/character_assembly.gd")

signal changed(description: String)

var assembly = null
var part_registry = null
var slot_registry = null
var body_types: Array = []
var weapons: Dictionary = {}
var palettes: Dictionary = {}
var outfits: Dictionary = {}
var presets: Dictionary = {}
var locked_part_ids: Array = []
var locked_palette_channels: Array = []
var _undo_stack: Array = []
var _redo_stack: Array = []


func configure(p_part_registry, p_slot_registry, p_body_types: Array, p_weapons: Array = []) -> void:
	part_registry = p_part_registry
	slot_registry = p_slot_registry
	body_types = p_body_types.duplicate()
	weapons.clear()
	for weapon in p_weapons:
		if weapon != null and not weapon.weapon_id.is_empty(): weapons[weapon.weapon_id] = weapon
	if assembly != null: assembly.configure(part_registry, slot_registry, body_types)


func create_character(character_id: String, display_name: String, body_type_id: String) -> Dictionary:
	assembly = AssemblyScript.new(character_id, display_name)
	assembly.configure(part_registry, slot_registry, body_types)
	var report: Dictionary = assembly.set_body_type(body_type_id)
	if report.get("success", false): changed.emit("Create character")
	return report


func browse_parts(filters: Dictionary = {}) -> Array:
	if part_registry == null: return []
	var applied := filters.duplicate(true)
	if assembly != null and not applied.has("body_type_id"): applied["body_type_id"] = assembly.body_type_id
	return part_registry.list_parts(applied)


func equip_part(part_id: String) -> Dictionary:
	if assembly == null: return _failure("Create a character before choosing parts.")
	var before := _snapshot()
	var report: Dictionary = assembly.equip_part(part_id)
	if report.get("success", false): _record(before, "Equip " + part_id)
	return report


func set_palette_channel(channel_id: String, value: Variant) -> bool:
	if assembly == null or channel_id in locked_palette_channels: return false
	var before := _snapshot()
	assembly.palette_values[channel_id] = value
	_record(before, "Set palette " + channel_id)
	return true


func add_palette(palette) -> bool:
	if palette == null or not palette.validate().is_empty() or palettes.has(palette.palette_id): return false
	palettes[palette.palette_id] = palette
	return true


func apply_palette(palette_id: String) -> Dictionary:
	if assembly == null or not palettes.has(palette_id): return _failure("Choose a registered palette.")
	var before := _snapshot()
	for channel_id in palettes[palette_id].channels:
		if channel_id not in locked_palette_channels: assembly.palette_values[channel_id] = palettes[palette_id].channels[channel_id]
	_record(before, "Apply palette " + palette_id)
	return {"success": true, "errors": [], "repair_actions": []}


func set_attachment_map(part_id: String, map: Dictionary) -> bool:
	if assembly == null or part_id not in assembly.get_equipped_part_ids(): return false
	var before := _snapshot()
	assembly.attachment_maps[part_id] = map.duplicate(true)
	_record(before, "Set attachment map " + part_id)
	return true


func save_outfit(outfit_id: String) -> bool:
	if assembly == null or outfit_id.strip_edges().is_empty(): return false
	outfits[outfit_id.strip_edges()] = {"equipped_by_slot": assembly.equipped_by_slot.duplicate(true), "palette_values": assembly.palette_values.duplicate(true), "attachment_maps": assembly.attachment_maps.duplicate(true)}
	return true


func apply_outfit(outfit_id: String) -> Dictionary:
	if assembly == null or not outfits.has(outfit_id): return _failure("Choose a saved outfit.")
	var before := _snapshot()
	var outfit: Dictionary = outfits[outfit_id]
	assembly.equipped_by_slot = outfit.equipped_by_slot.duplicate(true)
	assembly.palette_values = outfit.palette_values.duplicate(true)
	assembly.attachment_maps = outfit.attachment_maps.duplicate(true)
	var report: Dictionary = assembly.validate()
	if not report.get("success", false): apply_snapshot(before); return report
	_record(before, "Apply outfit " + outfit_id)
	return report


func lock_part(part_id: String, locked: bool = true) -> bool:
	if assembly == null or part_id not in assembly.get_equipped_part_ids(): return false
	if locked and part_id not in locked_part_ids: locked_part_ids.append(part_id)
	if not locked: locked_part_ids.erase(part_id)
	return true


func lock_palette_channel(channel_id: String, locked: bool = true) -> void:
	if locked and channel_id not in locked_palette_channels: locked_palette_channels.append(channel_id)
	if not locked: locked_palette_channels.erase(channel_id)


func randomize(seed: int) -> Dictionary:
	if assembly == null: return _failure("Create a character before randomizing.")
	var before := _snapshot()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for slot in slot_registry.list_slots():
		var current: Array = assembly.equipped_by_slot.get(slot.slot_id, [])
		var protected := false
		for part_id in current:
			if part_id in locked_part_ids: protected = true
		if protected: continue
		assembly.equipped_by_slot.erase(slot.slot_id)
		var choices: Array = browse_parts({"slot_id": slot.slot_id})
		if choices.is_empty(): continue
		var start := rng.randi_range(0, choices.size() - 1)
		var equipped := false
		for index in choices.size():
			var candidate = choices[(start + index) % choices.size()]
			var report: Dictionary = assembly.equip_part(candidate.part_id)
			if report.get("success", false): equipped = true; break
		if not equipped and slot.required:
			apply_snapshot(before)
			return _failure("No compatible part is available for required slot '%s'." % slot.slot_id)
	assembly.metadata["random_seed"] = seed
	var validation: Dictionary = assembly.validate()
	if not validation.get("success", false): apply_snapshot(before); return validation
	_record(before, "Randomize character")
	return validation


func save_preset(preset_id: String) -> bool:
	if assembly == null or preset_id.strip_edges().is_empty(): return false
	presets[preset_id.strip_edges()] = _snapshot()
	return true


func apply_preset(preset_id: String) -> bool:
	if not presets.has(preset_id): return false
	var before := _snapshot()
	apply_snapshot(presets[preset_id])
	_record(before, "Apply preset " + preset_id)
	return true


func equip_weapon(weapon_id: String) -> Dictionary:
	if assembly == null or not weapons.has(weapon_id): return _failure("Choose a registered weapon.")
	var weapon = weapons[weapon_id]
	var body = _body_type(assembly.body_type_id)
	if not weapon.is_compatible_with_body_type(assembly.body_type_id): return _failure("This weapon does not support the current body type.")
	if body != null and not body.supports_weapon_tags(Array(weapon.tags)): return _failure("This body type does not support the weapon's interaction tags.")
	var before := _snapshot()
	assembly.equipped_weapon_id = weapon_id
	_record(before, "Equip weapon " + weapon_id)
	return {"success": true, "errors": [], "repair_actions": []}


func generate_npc_batch(count: int, seed: int) -> Dictionary:
	if count < 1: return _failure("NPC batch count must be positive.")
	var result: Array = []
	var signatures: Dictionary = {}
	var attempt := 0
	while result.size() < count and attempt < count * 100:
		var index := result.size()
		var npc = get_script().new()
		npc.configure(part_registry, slot_registry, body_types, weapons.values())
		if npc.create_character("npc_%03d" % index, "NPC %03d" % index, assembly.body_type_id).get("success", false) == false: return _failure("NPC batch needs a valid body type.")
		var report: Dictionary = npc.randomize(seed + attempt * 7919)
		attempt += 1
		if not report.get("success", false): return report
		var data: Dictionary = npc.assembly.to_dict()
		var signature := str(data.equipped_by_slot) + str(data.palette_values)
		if not signatures.has(signature):
			signatures[signature] = true
			result.append(data)
		npc.free()
	if result.size() != count: return _failure("Not enough compatible variations to produce a distinct NPC batch.")
	return {"success": true, "characters": result, "errors": [], "repair_actions": []}


func undo() -> bool:
	if _undo_stack.is_empty(): return false
	_redo_stack.append(_snapshot())
	apply_snapshot(_undo_stack.pop_back())
	changed.emit("Undo character edit")
	return true


func redo() -> bool:
	if _redo_stack.is_empty(): return false
	_undo_stack.append(_snapshot())
	apply_snapshot(_redo_stack.pop_back())
	changed.emit("Redo character edit")
	return true


func to_dict() -> Dictionary:
	return {"assembly": assembly.to_dict() if assembly != null else {}, "outfits": outfits.duplicate(true), "presets": presets.duplicate(true), "locked_part_ids": locked_part_ids.duplicate(), "locked_palette_channels": locked_palette_channels.duplicate()}


func from_dict(data: Dictionary) -> bool:
	if not data.has("assembly") or (data.get("assembly", {}) as Dictionary).is_empty(): return false
	outfits = (data.get("outfits", {}) as Dictionary).duplicate(true)
	presets = (data.get("presets", {}) as Dictionary).duplicate(true)
	apply_snapshot(data)
	return assembly.validate().get("success", false)


func apply_snapshot(data: Dictionary) -> void:
	if not data.has("assembly"): return
	assembly = AssemblyScript.new().from_dict(data.assembly)
	assembly.configure(part_registry, slot_registry, body_types)
	locked_part_ids = data.get("locked_part_ids", []).duplicate()
	locked_palette_channels = data.get("locked_palette_channels", []).duplicate()


func _record(before: Dictionary, description: String) -> void:
	_undo_stack.append(before)
	_redo_stack.clear()
	changed.emit(description)


func _snapshot() -> Dictionary:
	return {"assembly": assembly.to_dict() if assembly != null else {}, "locked_part_ids": locked_part_ids.duplicate(), "locked_palette_channels": locked_palette_channels.duplicate()}


func _body_type(body_type_id: String):
	for body in body_types:
		if body.body_type_id == body_type_id: return body
	return null


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": [{"action": "resolve_character", "message": message}]}
