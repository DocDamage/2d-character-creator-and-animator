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
var _history_recorder: Callable


func set_history_recorder(recorder: Callable = Callable()) -> void:
	_history_recorder = recorder


func uses_document_history() -> bool:
	return _history_recorder.is_valid()


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


func unequip_part(part_id: String) -> bool:
	if assembly == null or part_id.strip_edges().is_empty(): return false
	var before := _snapshot()
	if not assembly.unequip_part(part_id): return false
	_record(before, "Unequip " + part_id)
	return true


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
	var before := _snapshot()
	var state := get_layer_state(part_id)
	if bool(state.get("locked", false)) == locked and ((part_id in locked_part_ids) == locked): return false
	if locked and part_id not in locked_part_ids: locked_part_ids.append(part_id)
	if not locked: locked_part_ids.erase(part_id)
	state["locked"] = locked
	_set_layer_state(part_id, state)
	_record(before, ("Locked " if locked else "Unlocked ") + _layer_name(part_id) + " Layer")
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


func can_undo() -> bool: return not _undo_stack.is_empty()
func can_redo() -> bool: return not _redo_stack.is_empty()


func get_layer_state(part_id: String) -> Dictionary:
	if assembly == null or part_id.strip_edges().is_empty(): return _default_layer_state()
	var states: Dictionary = assembly.metadata.get("layer_states", {})
	return _normalise_layer_state(states.get(part_id, {}))


func get_layer_ids_in_order() -> Array[String]:
	var result: Array[String] = []
	if assembly == null: return result
	var equipped: Array = assembly.get_equipped_part_ids()
	var order: Array = assembly.metadata.get("layer_order", []).duplicate()
	for part_id in order:
		var id := str(part_id)
		if id in equipped and id not in result: result.append(id)
	for part_id in equipped:
		var id := str(part_id)
		if id not in result: result.append(id)
	return result


func get_layer_transform_values(part_id: String) -> Dictionary:
	var state := get_layer_state(part_id)
	var position: Array = state.get("position", [0.0, 0.0])
	var scale: Array = state.get("scale", [1.0, 1.0])
	var pivot: Array = state.get("pivot", [0.5, 0.5])
	return {
		"pos_x": float(position[0]) if position.size() > 0 else 0.0,
		"pos_y": float(position[1]) if position.size() > 1 else 0.0,
		"rotation_deg": float(state.get("rotation_degrees", 0.0)),
		"scale_x": float(scale[0]) if scale.size() > 0 else 1.0,
		"scale_y": float(scale[1]) if scale.size() > 1 else 1.0,
		"pivot_x": float(pivot[0]) if pivot.size() > 0 else 0.5,
		"pivot_y": float(pivot[1]) if pivot.size() > 1 else 0.5,
		"opacity": float(state.get("opacity", 1.0)),
		"tint": (state.get("tint", [1.0, 1.0, 1.0, 1.0]) as Array).duplicate(),
		"visible": bool(state.get("visible", true)),
		"locked": bool(state.get("locked", false)),
	}


func set_layer_position(part_id: String, position: Vector2) -> bool:
	return _set_layer_values(part_id, {"position": [position.x, position.y]}, "Moved %s Layer" % _layer_name(part_id))


func set_layer_scale(part_id: String, scale: Vector2) -> bool:
	return _set_layer_values(part_id, {"scale": [maxf(0.01, scale.x), maxf(0.01, scale.y)]}, "Scaled %s Layer" % _layer_name(part_id))


func set_layer_rotation(part_id: String, rotation_degrees: float) -> bool:
	return _set_layer_values(part_id, {"rotation_degrees": rotation_degrees}, "Rotated %s Layer" % _layer_name(part_id))


func set_layer_pivot(part_id: String, pivot: Vector2) -> bool:
	return _set_layer_values(part_id, {"pivot": [clampf(pivot.x, 0.0, 1.0), clampf(pivot.y, 0.0, 1.0)]}, "Changed Pivot for %s Layer" % _layer_name(part_id))


func set_layer_opacity(part_id: String, opacity: float) -> bool:
	return _set_layer_values(part_id, {"opacity": clampf(opacity, 0.0, 1.0)}, "Changed Opacity for %s Layer" % _layer_name(part_id))


func set_layer_tint(part_id: String, tint: Color) -> bool:
	return _set_layer_values(part_id, {"tint": [tint.r, tint.g, tint.b, tint.a]}, "Tinted %s Layer" % _layer_name(part_id))


func set_layer_visibility(part_id: String, visible: bool) -> bool:
	return _set_layer_values(part_id, {"visible": visible}, ("Showed " if visible else "Hid ") + _layer_name(part_id) + " Layer", true)


func set_layer_locked(part_id: String, locked: bool) -> bool:
	return lock_part(part_id, locked)


func solo_layer(part_id: String) -> bool:
	if assembly == null or part_id not in assembly.get_equipped_part_ids(): return false
	var before := _snapshot()
	var current := str(assembly.metadata.get("solo_part_id", ""))
	assembly.metadata["solo_part_id"] = "" if current == part_id else part_id
	_record(before, ("Cleared solo for " if current == part_id else "Soloed ") + _layer_name(part_id) + " Layer")
	return true


func is_layer_effectively_visible(part_id: String) -> bool:
	var state := get_layer_state(part_id)
	if not bool(state.get("visible", true)): return false
	var solo := str(assembly.metadata.get("solo_part_id", "")) if assembly != null else ""
	return solo.is_empty() or solo == part_id


func reorder_layer(part_id: String, target_index: int) -> bool:
	if assembly == null or part_id not in assembly.get_equipped_part_ids(): return false
	var order := get_layer_ids_in_order()
	var current_index := order.find(part_id)
	if current_index < 0: return false
	var clamped := clampi(target_index, 0, max(0, order.size() - 1))
	if clamped == current_index: return false
	var before := _snapshot()
	order.remove_at(current_index)
	order.insert(clamped, part_id)
	assembly.metadata["layer_order"] = order
	_record(before, "Reordered %s Layer" % _layer_name(part_id))
	return true


func move_layer_by(part_id: String, delta: int) -> bool:
	var index := get_layer_ids_in_order().find(part_id)
	return reorder_layer(part_id, index + delta) if index >= 0 else false


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
	var after := _snapshot()
	if _history_recorder.is_valid():
		var handled: Variant = _history_recorder.call(before, after, description)
		if typeof(handled) == TYPE_BOOL and handled:
			return
	_undo_stack.append(before)
	_redo_stack.clear()
	changed.emit(description)


func _snapshot() -> Dictionary:
	return {"assembly": assembly.to_dict() if assembly != null else {}, "locked_part_ids": locked_part_ids.duplicate(), "locked_palette_channels": locked_palette_channels.duplicate()}


func _set_layer_values(part_id: String, updates: Dictionary, description: String, permit_locked: bool = false) -> bool:
	if assembly == null or part_id not in assembly.get_equipped_part_ids(): return false
	var state := get_layer_state(part_id)
	if bool(state.get("locked", false)) and not permit_locked: return false
	var next := state.duplicate(true)
	for key in updates: next[key] = updates[key]
	next = _normalise_layer_state(next)
	if next == state: return false
	var before := _snapshot()
	_set_layer_state(part_id, next)
	_record(before, description)
	return true


func _set_layer_state(part_id: String, state: Dictionary) -> void:
	if assembly == null: return
	var states: Dictionary = assembly.metadata.get("layer_states", {}).duplicate(true)
	states[part_id] = _normalise_layer_state(state)
	assembly.metadata["layer_states"] = states
	var order := get_layer_ids_in_order()
	if part_id not in order:
		order.append(part_id)
	assembly.metadata["layer_order"] = order


func _default_layer_state() -> Dictionary:
	return {
		"position": [0.0, 0.0], "scale": [1.0, 1.0], "rotation_degrees": 0.0,
		"pivot": [0.5, 0.5], "opacity": 1.0, "tint": [1.0, 1.0, 1.0, 1.0],
		"visible": true, "locked": false,
	}


func _normalise_layer_state(candidate: Dictionary) -> Dictionary:
	var state := _default_layer_state()
	for key in candidate:
		state[key] = candidate[key]
	var position: Array = state.get("position", [])
	var scale: Array = state.get("scale", [])
	var pivot: Array = state.get("pivot", [])
	var tint: Array = state.get("tint", [])
	state["position"] = [float(position[0]) if position.size() > 0 else 0.0, float(position[1]) if position.size() > 1 else 0.0]
	state["scale"] = [maxf(0.01, float(scale[0]) if scale.size() > 0 else 1.0), maxf(0.01, float(scale[1]) if scale.size() > 1 else 1.0)]
	state["pivot"] = [clampf(float(pivot[0]) if pivot.size() > 0 else 0.5, 0.0, 1.0), clampf(float(pivot[1]) if pivot.size() > 1 else 0.5, 0.0, 1.0)]
	state["rotation_degrees"] = float(state.get("rotation_degrees", 0.0))
	state["opacity"] = clampf(float(state.get("opacity", 1.0)), 0.0, 1.0)
	state["tint"] = [clampf(float(tint[0]) if tint.size() > 0 else 1.0, 0.0, 1.0), clampf(float(tint[1]) if tint.size() > 1 else 1.0, 0.0, 1.0), clampf(float(tint[2]) if tint.size() > 2 else 1.0, 0.0, 1.0), clampf(float(tint[3]) if tint.size() > 3 else 1.0, 0.0, 1.0)]
	state["visible"] = bool(state.get("visible", true))
	state["locked"] = bool(state.get("locked", false))
	return state


func _layer_name(part_id: String) -> String:
	var part = part_registry.get_part(part_id) if part_registry != null else null
	return str(part.display_name) if part != null else part_id


func _body_type(body_type_id: String):
	for body in body_types:
		if body.body_type_id == body_type_id: return body
	return null


func _failure(message: String) -> Dictionary:
	return {"success": false, "errors": [message], "repair_actions": [{"action": "resolve_character", "message": message}]}
