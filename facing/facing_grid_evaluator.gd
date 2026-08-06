# FacingGridEvaluator -- Selects and blends neighboring directional cells.
class_name FacingGridEvaluator
extends RefCounted

const FacingGridDefinitionScript = preload("res://facing/facing_grid_definition.gd")
const FacingMeshBlendModelScript = preload("res://facing/facing_mesh_blend_model.gd")


static func evaluate(grid, direction: Vector2, blend_mode: int = -1) -> Dictionary:
	if grid == null or grid.get_direction_ids().is_empty():
		return {"valid": false, "reason": "grid has no directions"}
	var directions: Array = grid.get_direction_ids()
	var mode: int = grid.default_blend_mode if blend_mode < 0 else blend_mode
	if grid.pixel_mode:
		mode = FacingGridDefinitionScript.BlendMode.HARD_SWITCH
	var angle: float = _vector_to_angle(direction)
	var interval: float = TAU / float(directions.size())
	var position: float = fposmod(angle, TAU) / interval
	var lower_index: int = int(floor(position)) % directions.size()
	var fraction: float = position - floor(position)
	var upper_index: int = (lower_index + 1) % directions.size()
	var nearest_index: int = lower_index if fraction < 0.5 else upper_index
	if mode != FacingGridDefinitionScript.BlendMode.CROSSFADE:
		return _single_cell(grid, directions[nearest_index], angle)
	var from_id: String = directions[lower_index]
	var to_id: String = directions[upper_index]
	var from_cell: Dictionary = grid.get_cell(from_id)
	var to_cell: Dictionary = grid.get_cell(to_id)
	if not bool(from_cell.get("blend_enabled", true)) or not bool(to_cell.get("blend_enabled", true)):
		return _single_cell(grid, directions[nearest_index], angle)
	var mesh_blend := FacingMeshBlendModelScript.evaluate_cells(from_cell, to_cell, fraction)
	return {
		"valid": true,
		"mode": "crossfade",
		"direction_angle": angle,
		"primary_direction": from_id,
		"secondary_direction": to_id,
		"primary_cell": from_cell,
		"secondary_cell": to_cell,
		"weight": fraction,
		"mesh_blend": mesh_blend,
	}


static func interpolate_mesh_vertices(from_vertices: Array, to_vertices: Array, weight: float) -> Array:
	var result: Array = []
	if from_vertices.size() != to_vertices.size():
		return result
	for index in range(from_vertices.size()):
		var from_value = from_vertices[index]
		var to_value = to_vertices[index]
		if from_value is Vector2 and to_value is Vector2:
			result.append((from_value as Vector2).lerp(to_value as Vector2, clampf(weight, 0.0, 1.0)))
		elif from_value is Array and to_value is Array and from_value.size() >= 2 and to_value.size() >= 2:
			var a := Vector2(float(from_value[0]), float(from_value[1]))
			var b := Vector2(float(to_value[0]), float(to_value[1]))
			var point := a.lerp(b, clampf(weight, 0.0, 1.0))
			result.append([point.x, point.y])
		else:
			return []
	return result


static func _single_cell(grid, direction_id: String, angle: float) -> Dictionary:
	return {
		"valid": true,
		"mode": "hard_switch",
		"direction_angle": angle,
		"primary_direction": direction_id,
		"secondary_direction": "",
		"primary_cell": grid.get_cell(direction_id),
		"secondary_cell": {},
		"weight": 0.0,
		"mesh_blend": {"compatible": false, "reason": "Hard direction switching is active.", "vertices": [], "weight": 0.0},
	}


static func _vector_to_angle(direction: Vector2) -> float:
	if direction.is_zero_approx():
		return 0.0
	return fposmod(atan2(direction.x, -direction.y), TAU)
