# FacingGridDefinition -- Serializable directional variants for modular character parts.
class_name FacingGridDefinition
extends RefCounted

const SCHEMA_VERSION := "1.0.0"

enum DirectionSet { CUSTOM = 0, FOUR_WAY = 4, EIGHT_WAY = 8, SIXTEEN_WAY = 16 }
enum BlendMode { HARD_SWITCH, NEAREST, CROSSFADE }

const FOUR_WAY := ["north", "east", "south", "west"]
const EIGHT_WAY := ["north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"]

var grid_id: String = ""
var display_name: String = "Untitled Facing Grid"
var direction_set: DirectionSet = DirectionSet.EIGHT_WAY
var custom_directions: Array = []
var cells: Dictionary = {}
var pixel_mode: bool = false
var default_blend_mode: BlendMode = BlendMode.HARD_SWITCH


func _init(p_grid_id: String = "", p_display_name: String = "Untitled Facing Grid") -> void:
	grid_id = p_grid_id
	display_name = p_display_name


func get_direction_ids() -> Array:
	match direction_set:
		DirectionSet.FOUR_WAY:
			return FOUR_WAY.duplicate()
		DirectionSet.EIGHT_WAY:
			return EIGHT_WAY.duplicate()
		DirectionSet.SIXTEEN_WAY:
			var directions: Array = []
			for index in range(16):
				directions.append("direction_%02d" % index)
			return directions
		_:
			return custom_directions.duplicate()


func set_direction_set(value: DirectionSet, directions: Array = []) -> void:
	direction_set = value
	if value == DirectionSet.CUSTOM:
		custom_directions = _unique_strings(directions)
	_prune_unknown_cells()


func set_cell(direction_id: String, value: Dictionary) -> bool:
	if direction_id not in get_direction_ids():
		return false
	var cell := _normalise_cell(value)
	cells[direction_id] = cell
	return true


func get_cell(direction_id: String) -> Dictionary:
	return (cells.get(direction_id, {}) as Dictionary).duplicate(true)


func remove_cell(direction_id: String) -> bool:
	if not cells.has(direction_id):
		return false
	cells.erase(direction_id)
	return true


func swap_cell_slots(direction_id: String) -> bool:
	if not cells.has(direction_id):
		return false
	var cell := get_cell(direction_id)
	var slots := cell.get("slot_swap", {}) as Dictionary
	if slots.is_empty():
		return false
	cell["slot_swap"] = _swap_left_right_slots(slots)
	return set_cell(direction_id, cell)


func mirror_cell(source_direction: String, destination_direction: String, swap_slots: bool = true) -> bool:
	if source_direction not in cells or destination_direction not in get_direction_ids():
		return false
	var copy := get_cell(source_direction)
	copy["mirrored_from"] = source_direction
	copy["mirror_x"] = not bool(copy.get("mirror_x", false))
	copy["handedness_swap"] = not bool(copy.get("handedness_swap", false))
	if swap_slots:
		copy["slot_swap"] = _swap_left_right_slots(copy.get("slot_swap", {}) as Dictionary)
	return set_cell(destination_direction, copy)


func missing_directions() -> Array:
	var missing: Array = []
	for direction_id in get_direction_ids():
		if not cells.has(direction_id):
			missing.append(direction_id)
	return missing


func validate() -> Array:
	var errors: Array = []
	if grid_id.is_empty():
		errors.append("grid_id is required")
	if display_name.is_empty():
		errors.append("display_name is required")
	if get_direction_ids().size() < 2:
		errors.append("a facing grid needs at least two directions")
	for direction_id in cells:
		if direction_id not in get_direction_ids():
			errors.append("cell has unknown direction: " + str(direction_id))
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"grid_id": grid_id,
		"display_name": display_name,
		"direction_set": int(direction_set),
		"custom_directions": custom_directions.duplicate(),
		"cells": cells.duplicate(true),
		"pixel_mode": pixel_mode,
		"default_blend_mode": int(default_blend_mode),
	}


func from_dict(data: Dictionary) -> FacingGridDefinition:
	grid_id = str(data.get("grid_id", ""))
	display_name = str(data.get("display_name", "Untitled Facing Grid"))
	direction_set = int(data.get("direction_set", DirectionSet.EIGHT_WAY)) as DirectionSet
	custom_directions = _unique_strings(data.get("custom_directions", []) as Array)
	cells.clear()
	for direction_id in (data.get("cells", {}) as Dictionary):
		if direction_id in get_direction_ids():
			cells[direction_id] = _normalise_cell(data["cells"][direction_id] as Dictionary)
	pixel_mode = bool(data.get("pixel_mode", false))
	default_blend_mode = int(data.get("default_blend_mode", BlendMode.HARD_SWITCH)) as BlendMode
	return self


func direction_angles() -> Array:
	var count := get_direction_ids().size()
	var angles: Array = []
	for index in range(count):
		angles.append(float(index) * TAU / float(count))
	return angles


func _normalise_cell(value: Dictionary) -> Dictionary:
	var offset: Variant = value.get("offset", [0.0, 0.0])
	if offset is Vector2:
		offset = [offset.x, offset.y]
	return {
		"asset_id": str(value.get("asset_id", "")),
		"mesh_id": str(value.get("mesh_id", "")),
		"offset": offset,
		"rotation": float(value.get("rotation", 0.0)),
		"scale": value.get("scale", [1.0, 1.0]),
		"visible": bool(value.get("visible", true)),
		"z_index": int(value.get("z_index", 0)),
		"deformation": (value.get("deformation", {}) as Dictionary).duplicate(true),
		"mirror_x": bool(value.get("mirror_x", false)),
		"mirrored_from": str(value.get("mirrored_from", "")),
		"handedness_swap": bool(value.get("handedness_swap", false)),
		"slot_swap": (value.get("slot_swap", {}) as Dictionary).duplicate(true),
		"blend_enabled": bool(value.get("blend_enabled", true)),
	}


func _prune_unknown_cells() -> void:
	for direction_id in cells.keys():
		if direction_id not in get_direction_ids():
			cells.erase(direction_id)


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var direction_id := str(value).strip_edges()
		if not direction_id.is_empty() and direction_id not in result:
			result.append(direction_id)
	return result


func _swap_left_right_slots(slots: Dictionary) -> Dictionary:
	var swapped: Dictionary = {}
	for key in slots:
		var replacement := str(slots[key])
		replacement = replacement.replace("_left", "_temp").replace("_right", "_left").replace("_temp", "_right")
		swapped[str(key)] = replacement
	return swapped
