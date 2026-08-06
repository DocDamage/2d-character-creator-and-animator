# InteractiveOnionController -- Interactive ghost selection and key tweaking.
# ONI-003: Provides hit testing and direct manipulation of keyframes via onion skin ghosts.
class_name InteractiveOnionController
extends RefCounted

signal ghost_selected(ghost_time: float, part_id: String)
signal ghost_dragged(ghost_time: float, part_id: String, new_position: Vector2)

var is_ghost_selection_enabled: bool = true
var active_ghost_time: float = -1.0
var active_part_id: String = ""
var hit_radius: float = 16.0


## Performs hit testing against ghost overlay positions in canvas world coordinates.
## ghost_positions: Dictionary of { "time_part_id": Vector2(world_x, world_y) }
func hit_test_ghosts(click_pos: Vector2, ghost_positions: Dictionary) -> Dictionary:
	if not is_ghost_selection_enabled:
		return {}

	var closest_key: String = ""
	var closest_dist: float = hit_radius

	for key in ghost_positions.keys():
		var pos: Vector2 = ghost_positions[key] as Vector2
		var dist: float = click_pos.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_key = str(key)

	if not closest_key.is_empty():
		var parts: Array = closest_key.split(":")
		if parts.size() >= 2:
			var g_time: float = float(parts[0])
			var p_id: String = parts[1]
			select_ghost(g_time, p_id)
			return {"time": g_time, "part_id": p_id, "distance": closest_dist}

	return {}


## Selects active ghost frame and part ID.
func select_ghost(ghost_time: float, part_id: String) -> void:
	active_ghost_time = ghost_time
	active_part_id = part_id
	ghost_selected.emit(ghost_time, part_id)


## Deselects active ghost overlay.
func clear_selection() -> void:
	active_ghost_time = -1.0
	active_part_id = ""


## Triggers drag update for active ghost.
func drag_active_ghost(new_position: Vector2) -> void:
	if active_ghost_time >= 0.0 and not active_part_id.is_empty():
		ghost_dragged.emit(active_ghost_time, active_part_id, new_position)
