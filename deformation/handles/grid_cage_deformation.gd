# GridCageDeformation -- Legacy radial pins plus an explicit true polygon cage implementation.
# DEF-001 retained radial-pin compatibility; new LPC code uses ordered mean-value cages below.
class_name GridCageDeformation
extends RefCounted

const LpcCageScript = preload("res://lpc/rig/lpc_cage_deformation.gd")

## Pin control point schema.
class PinPoint:
	extends RefCounted
	var pin_id: String = ""
	var rest_position: Vector2 = Vector2.ZERO
	var current_position: Vector2 = Vector2.ZERO
	var radius: float = 64.0
	var weight: float = 1.0

	func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_radius: float = 64.0) -> void:
		pin_id = p_id
		rest_position = p_pos
		current_position = p_pos
		radius = p_radius

	func get_offset() -> Vector2:
		return current_position - rest_position


var pins: Array = [] # Array of PinPoint
var cage_rect: Rect2 = Rect2(0, 0, 100, 100)
var true_cage: Dictionary = {}


func add_pin(pin_id: String, rest_pos: Vector2, radius: float = 64.0) -> PinPoint:
	var pin := PinPoint.new(pin_id, rest_pos, radius)
	pins.append(pin)
	return pin


func move_pin(pin_id: String, new_pos: Vector2) -> void:
	for pin in pins:
		if pin.pin_id == pin_id:
			pin.current_position = new_pos
			break


## Computes vertex displacement offset using radial basis function (RBF) inverse distance weighting.
func evaluate_vertex_displacement(vertex_pos: Vector2) -> Vector2:
	if pins.is_empty():
		return Vector2.ZERO

	var total_offset := Vector2.ZERO
	var total_weight: float = 0.0

	for pin in pins:
		var dist: float = vertex_pos.distance_to(pin.rest_position)
		if dist <= pin.radius:
			var norm_d: float = dist / pin.radius
			var w: float = pow(1.0 - norm_d, 2.0) * pin.weight
			total_offset += pin.get_offset() * w
			total_weight += w

	if total_weight > 0.0:
		return total_offset / maxf(total_weight, 1.0)
	return Vector2.ZERO


## Explicitly configures an ordered polygon cage. Radial pins remain independent.
func set_true_cage(rest_vertices: Array, current_vertices: Array = []) -> Array[String]:
	true_cage = LpcCageScript.create(rest_vertices, {"vertices": current_vertices if not current_vertices.is_empty() else rest_vertices})
	return LpcCageScript.validate(true_cage)


func move_cage_vertex(index: int, position: Vector2) -> Array[String]:
	if true_cage.is_empty(): return ["Create a true cage before moving cage vertices."]
	true_cage = LpcCageScript.move_vertex(true_cage, index, position)
	return LpcCageScript.validate(true_cage)


func evaluate_true_cage_position(vertex_pos: Vector2) -> Vector2:
	return LpcCageScript.deform_position(true_cage, vertex_pos) if not true_cage.is_empty() else vertex_pos


func deform_with_true_cage(rest_positions: Array[Vector2]) -> Array[Vector2]:
	return LpcCageScript.deform_positions(true_cage, rest_positions) if not true_cage.is_empty() else rest_positions.duplicate()


## Applies cage deformation displacement to an array of vertex positions.
func deform_vertex_positions(rest_positions: Array[Vector2]) -> Array[Vector2]:
	var deformed: Array[Vector2] = []
	for pos in rest_positions:
		var offset: Vector2 = evaluate_vertex_displacement(pos)
		deformed.append(pos + offset)
	return deformed
