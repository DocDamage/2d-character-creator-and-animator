# LpcCageDeformation -- Ordered polygon cage deformation using mean-value coordinates, separate from radial pins.
class_name LpcCageDeformation
extends RefCounted

const SCHEMA_VERSION := "1.0.0"


static func create(rest_vertices: Array, options: Dictionary = {}) -> Dictionary:
	var points := _serialize(rest_vertices)
	return {"cage_schema_version": SCHEMA_VERSION, "cage_id": str(options.get("cage_id", "cage_" + str(Time.get_ticks_usec()))), "rest_vertices": points, "vertices": _serialize(options.get("vertices", points)), "locked_indices": (options.get("locked_indices", []) as Array).duplicate(true), "coordinate_model": "mean_value_coordinates"}


static func validate(cage: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(cage.get("cage_schema_version", "")) != SCHEMA_VERSION: errors.append("Unsupported LPC cage schema.")
	var rest := _vectors(cage.get("rest_vertices", [])); var current := _vectors(cage.get("vertices", []))
	if rest.size() < 3 or rest.size() != current.size(): errors.append("A true cage needs matching ordered rest and current polygons with at least three vertices.")
	if not _simple(rest) or not _simple(current): errors.append("LPC cage boundary self-intersects.")
	return errors


static func move_vertex(cage: Dictionary, index: int, position: Variant) -> Dictionary:
	var result := cage.duplicate(true); var vertices: Array = (result.get("vertices", []) as Array).duplicate(true)
	if index < 0 or index >= vertices.size() or index in result.get("locked_indices", []): return result
	var point := _vector(position); vertices[index] = [point.x, point.y]; result["vertices"] = vertices
	return result


static func deform_position(cage: Dictionary, point: Variant) -> Vector2:
	if not validate(cage).is_empty(): return _vector(point)
	var source := _vectors(cage.get("rest_vertices", [])); var target := _vectors(cage.get("vertices", [])); var position := _vector(point)
	for index in range(source.size()): if source[index].distance_to(position) < 0.00001: return target[index]
	if not _inside(source, position): return position
	var weights: Array[float] = []; var total := 0.0
	for index in range(source.size()):
		var current := source[index] - position; var previous := source[(index - 1 + source.size()) % source.size()] - position; var next := source[(index + 1) % source.size()] - position
		var length := current.length(); var before := atan2(_cross(previous, current), previous.dot(current)); var after := atan2(_cross(current, next), current.dot(next))
		var weight := (tan(before * 0.5) + tan(after * 0.5)) / maxf(length, 0.00001)
		weights.append(weight); total += weight
	if absf(total) < 0.00001: return position
	var result := Vector2.ZERO
	for index in range(target.size()): result += target[index] * (weights[index] / total)
	return result


static func deform_positions(cage: Dictionary, values: Array) -> Array[Vector2]:
	var output: Array[Vector2] = []
	for value in values: output.append(deform_position(cage, value))
	return output


static func _simple(points: Array[Vector2]) -> bool:
	if points.size() < 3: return false
	for a in range(points.size()):
		var a2 := (a + 1) % points.size()
		for b in range(a + 1, points.size()):
			var b2 := (b + 1) % points.size()
			if a == b or a2 == b or b2 == a: continue
			if _segments_intersect(points[a], points[a2], points[b], points[b2]): return false
	return true
static func _inside(points: Array[Vector2], point: Vector2) -> bool:
	var inside := false
	for index in range(points.size()):
		var a := points[index]; var b := points[(index + 1) % points.size()]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x: inside = not inside
	return inside
static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := _cross(b - a, c - a); var ab_d := _cross(b - a, d - a); var cd_a := _cross(d - c, a - c); var cd_b := _cross(d - c, b - c)
	return ((ab_c > 0.0 and ab_d < 0.0) or (ab_c < 0.0 and ab_d > 0.0)) and ((cd_a > 0.0 and cd_b < 0.0) or (cd_a < 0.0 and cd_b > 0.0))
static func _cross(a: Vector2, b: Vector2) -> float: return a.x * b.y - a.y * b.x
static func _vectors(values: Array) -> Array[Vector2]:
	var output: Array[Vector2] = []
	for value in values:
		output.append(_vector(value))
	return output
static func _serialize(values: Array) -> Array:
	var output: Array = []; for value in values:
		var point := _vector(value); output.append([point.x, point.y])
	return output
static func _vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Vector2i: return Vector2(value)
	if value is Array and (value as Array).size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
