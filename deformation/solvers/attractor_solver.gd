# AttractorSolver -- Point and line attractor force field solvers for dynamic deformation.
# DEF-002: Solves force attraction/repulsion field displacements for soft tissue and cloth effects.
class_name AttractorSolver
extends RefCounted

enum Type {
	POINT_ATTRACTOR = 0,
	POINT_REPULSOR = 1,
	LINE_ATTRACTOR = 2
}

class AttractorField:
	extends RefCounted
	var field_id: String = ""
	var type: int = Type.POINT_ATTRACTOR
	var position: Vector2 = Vector2.ZERO # or line start
	var position_end: Vector2 = Vector2.ZERO # for line attractor
	var radius: float = 128.0
	var strength: float = 1.0 # force magnitude

	func _init(p_id: String = "", p_type: int = Type.POINT_ATTRACTOR, p_pos: Vector2 = Vector2.ZERO) -> void:
		field_id = p_id
		type = p_type
		position = p_pos


var fields: Array = [] # Array of AttractorField


func add_point_attractor(field_id: String, pos: Vector2, radius: float = 128.0, strength: float = 1.0) -> AttractorField:
	var f := AttractorField.new(field_id, Type.POINT_ATTRACTOR, pos)
	f.radius = radius
	f.strength = strength
	fields.append(f)
	return f


func add_line_attractor(field_id: String, line_start: Vector2, line_end: Vector2, radius: float = 128.0, strength: float = 1.0) -> AttractorField:
	var f := AttractorField.new(field_id, Type.LINE_ATTRACTOR, line_start)
	f.position_end = line_end
	f.radius = radius
	f.strength = strength
	fields.append(f)
	return f


## Evaluates net force displacement offset vector on a vertex position.
func solve_displacement(vertex_pos: Vector2) -> Vector2:
	var total_force := Vector2.ZERO

	for f in fields:
		match f.type:
			Type.POINT_ATTRACTOR:
				var delta: Vector2 = (f.position as Vector2) - vertex_pos
				var dist: float = delta.length()
				if dist > 0.0 and dist <= f.radius:
					var norm_dist: float = dist / f.radius
					var mag: float = (1.0 - norm_dist) * f.strength * 10.0
					total_force += delta.normalized() * mag

			Type.POINT_REPULSOR:
				var delta: Vector2 = vertex_pos - (f.position as Vector2)
				var dist: float = delta.length()
				if dist > 0.0 and dist <= f.radius:
					var norm_dist: float = dist / f.radius
					var mag: float = (1.0 - norm_dist) * f.strength * 10.0
					total_force += delta.normalized() * mag

			Type.LINE_ATTRACTOR:
				var proj: Vector2 = closest_point_on_segment(vertex_pos, f.position, f.position_end)
				var delta: Vector2 = proj - vertex_pos
				var dist: float = delta.length()
				if dist > 0.0 and dist <= f.radius:
					var norm_dist: float = dist / f.radius
					var mag: float = (1.0 - norm_dist) * f.strength * 10.0
					total_force += delta.normalized() * mag

	return total_force


static func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var l2: float = a.distance_squared_to(b)
	if l2 == 0.0:
		return a
	var t: float = clampf((p - a).dot(b - a) / l2, 0.0, 1.0)
	return a + t * (b - a)
