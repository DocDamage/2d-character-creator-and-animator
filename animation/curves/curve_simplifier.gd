# CurveSimplifier -- Ramer-Douglas-Peucker curve simplification algorithm for keyframe reduction.
# CRV-007: Simplifies dense keyframe tracks by removing redundant keys within tolerance epsilon.
class_name CurveSimplifier
extends RefCounted

const LinearSteppedEvaluatorScript = preload("res://animation/curves/linear_stepped_evaluator.gd")


## Simplifies an array of keyframes using Ramer-Douglas-Peucker algorithm.
static func simplify_keyframes(keys: Array, epsilon: float = 0.01) -> Array:
	if keys.size() <= 2:
		return keys.duplicate()

	var points: Array[Vector2] = []
	for k in keys:
		var time_val: float = float(k.get("time")) if k != null else 0.0
		var scalar_val: float = extract_scalar_val(k.get("value")) if k != null else 0.0
		points.append(Vector2(time_val, scalar_val))

	var keep_indices: Array[bool] = []
	keep_indices.resize(points.size())
	keep_indices.fill(false)
	keep_indices[0] = true
	keep_indices[points.size() - 1] = true

	rdp_recursive(points, 0, points.size() - 1, epsilon, keep_indices)

	var result: Array = []
	for i in range(keys.size()):
		if keep_indices[i]:
			result.append(keys[i])

	return result


## RDP recursive line segment distance partitioning.
static func rdp_recursive(points: Array[Vector2], start_idx: int, end_idx: int, epsilon: float, keep_indices: Array[bool]) -> void:
	if end_idx <= start_idx + 1:
		return

	var max_dist: float = 0.0
	var max_idx: int = start_idx

	var p_start: Vector2 = points[start_idx]
	var p_end: Vector2 = points[end_idx]

	for i in range(start_idx + 1, end_idx):
		var dist: float = perpendicular_distance(points[i], p_start, p_end)
		if dist > max_dist:
			max_dist = dist
			max_idx = i

	if max_dist > epsilon:
		keep_indices[max_idx] = true
		rdp_recursive(points, start_idx, max_idx, epsilon, keep_indices)
		rdp_recursive(points, max_idx, end_idx, epsilon, keep_indices)


## Calculates perpendicular distance from point p to line segment (p1, p2).
static func perpendicular_distance(p: Vector2, p1: Vector2, p2: Vector2) -> float:
	if p1.distance_squared_to(p2) < 1e-12:
		return p.distance_to(p1)

	var line_vec: Vector2 = p2 - p1
	var num: float = absf(line_vec.y * p.x - line_vec.x * p.y + p2.x * p1.y - p2.y * p1.x)
	var den: float = line_vec.length()
	return num / den if den > 0.0 else 0.0


## Extracts a scalar float representation from a key value variant.
static func extract_scalar_val(val: Variant) -> float:
	match typeof(val):
		TYPE_FLOAT, TYPE_INT:
			return float(val)
		TYPE_VECTOR2:
			return (val as Vector2).length()
		TYPE_VECTOR3:
			return (val as Vector3).length()
		_:
			return 0.0


## Bakes an interpolated curve into discrete keyframes at fixed frame step intervals.
static func bake_curve(key_a: RefCounted, key_b: RefCounted, step_sec: float = 0.0333) -> Array:
	var baked: Array = []
	var time_a: float = float(key_a.get("time")) if key_a != null else 0.0
	var time_b: float = float(key_b.get("time")) if key_b != null else 0.0

	if key_a == null or key_b == null or time_a >= time_b:
		if key_a != null:
			baked.append(key_a)
		return baked

	var curr_time: float = time_a
	var idx: int = 0

	var KeyframeSchemaScript = preload("res://animation/keys/keyframe_schema.gd")

	while curr_time <= time_b:
		var val: Variant = LinearSteppedEvaluatorScript.evaluate_linear(key_a, key_b, curr_time)
		var k = KeyframeSchemaScript.new("baked_%d" % idx, curr_time, val)
		baked.append(k)
		curr_time += step_sec
		idx += 1

	if baked.is_empty() or float(baked.back().get("time")) < time_b:
		baked.append(key_b)

	return baked
