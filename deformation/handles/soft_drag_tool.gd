# SoftDragTool -- Interactive falloff/radius vertex drag deformation tool.
# DEF-003: Computes smooth radial falloff vertex displacements during direct canvas drags.
class_name SoftDragTool
extends RefCounted

var drag_radius: float = 48.0
var falloff_exponent: float = 1.5
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO


## Begins a soft drag gesture at start_pos.
func start_drag(start_pos: Vector2) -> void:
	drag_start_pos = start_pos
	is_dragging = true


## Ends active drag gesture.
func end_drag() -> void:
	is_dragging = false


## Evaluates updated vertex positions given current drag position and total offset vector.
func evaluate_drag_offsets(vertices: Array, current_pos: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not is_dragging or drag_radius <= 0.0:
		for v in vertices:
			result.append(v.position as Vector2)
		return result

	var drag_delta: Vector2 = current_pos - drag_start_pos

	for v in vertices:
		var rest_pos: Vector2 = v.position as Vector2
		var dist: float = rest_pos.distance_to(drag_start_pos)

		if dist <= drag_radius:
			var norm_dist: float = dist / drag_radius
			var factor: float = pow(1.0 - norm_dist, falloff_exponent)
			result.append(rest_pos + drag_delta * factor)
		else:
			result.append(rest_pos)

	return result
