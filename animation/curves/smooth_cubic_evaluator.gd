# SmoothCubicEvaluator -- Smooth Hermite and Catmull-Rom cubic spline interpolation.
# CRV-002: Evaluates smooth cubic curves across keyframe sequences with easing weights.
class_name SmoothCubicEvaluator
extends RefCounted

const LinearSteppedEvaluatorScript = preload("res://animation/curves/linear_stepped_evaluator.gd")


## Evaluates Hermite cubic interpolation between P1 and P2 with tangents M1 and M2 at normalized factor t (0..1).
static func cubic_hermite(p1: float, p2: float, m1: float, m2: float, t: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10: float = t3 - 2.0 * t2 + t
	var h01: float = -2.0 * t3 + 3.0 * t2
	var h11: float = t3 - t2
	return h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2


## Evaluates Catmull-Rom cubic spline through four points (p0, p1, p2, p3) at normalized factor t (0..1).
static func catmull_rom(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var m1: float = 0.5 * (p2 - p0)
	var m2: float = 0.5 * (p3 - p1)
	return cubic_hermite(p1, p2, m1, m2, t)


## Evaluates smooth cubic spline between key_1 and key_2 in a key sequence.
static func evaluate_smooth(key_1: RefCounted, key_2: RefCounted, t: float, key_prev: RefCounted = null, key_next: RefCounted = null) -> Variant:
	if key_1 == null and key_2 == null:
		return 0.0
	if key_1 == null:
		return key_2.get("value")
	var time_1: float = float(key_1.get("time")) if key_1 != null else 0.0
	var time_2: float = float(key_2.get("time")) if key_2 != null else 0.0
	if key_2 == null or time_1 == time_2:
		return key_1.get("value")

	var time_span: float = time_2 - time_1
	if time_span <= 0.0:
		return key_1.get("value")

	var factor: float = clampf((t - time_1) / time_span, 0.0, 1.0)
	var easing_adj: float = float(key_1.get("easing")) if key_1.get("easing") != null else 0.5

	var adjusted_factor: float = ease_factor(factor, easing_adj)
	return interpolate_smooth_values(key_1.get("value"), key_2.get("value"), adjusted_factor, key_prev, key_next)


## S-curve easing adjustment function based on keyframe easing weight (0.0..1.0).
static func ease_factor(factor: float, easing: float) -> float:
	if absf(easing - 0.5) < 0.001:
		return factor * factor * (3.0 - 2.0 * factor)

	var p: float = pow(factor, lerpf(0.5, 2.0, easing))
	return p * p * (3.0 - 2.0 * p)


## Smooth value interpolation helper.
static func interpolate_smooth_values(val_a: Variant, val_b: Variant, factor: float, key_prev: RefCounted = null, key_next: RefCounted = null) -> Variant:
	var prev_val: Variant = key_prev.get("value") if key_prev != null else null
	var next_val: Variant = key_next.get("value") if key_next != null else null

	match typeof(val_a):
		TYPE_FLOAT, TYPE_INT:
			var p1: float = float(val_a)
			var p2: float = float(val_b)
			var p0: float = float(prev_val) if (prev_val != null and (typeof(prev_val) == TYPE_FLOAT or typeof(prev_val) == TYPE_INT)) else p1
			var p3: float = float(next_val) if (next_val != null and (typeof(next_val) == TYPE_FLOAT or typeof(next_val) == TYPE_INT)) else p2
			return catmull_rom(p0, p1, p2, p3, factor)
		TYPE_VECTOR2:
			var v1: Vector2 = val_a as Vector2
			var v2: Vector2 = val_b as Vector2
			var v0: Vector2 = prev_val as Vector2 if (prev_val != null and typeof(prev_val) == TYPE_VECTOR2) else v1
			var v3: Vector2 = next_val as Vector2 if (next_val != null and typeof(next_val) == TYPE_VECTOR2) else v2
			return Vector2(
				catmull_rom(v0.x, v1.x, v2.x, v3.x, factor),
				catmull_rom(v0.y, v1.y, v2.y, v3.y, factor)
			)
		TYPE_VECTOR3:
			var u1: Vector3 = val_a as Vector3
			var u2: Vector3 = val_b as Vector3
			var u0: Vector3 = prev_val as Vector3 if (prev_val != null and typeof(prev_val) == TYPE_VECTOR3) else u1
			var u3: Vector3 = next_val as Vector3 if (next_val != null and typeof(next_val) == TYPE_VECTOR3) else u2
			return Vector3(
				catmull_rom(u0.x, u1.x, u2.x, u3.x, factor),
				catmull_rom(u0.y, u1.y, u2.y, u3.y, factor),
				catmull_rom(u0.z, u1.z, u2.z, u3.z, factor)
			)
		_:
			return LinearSteppedEvaluatorScript.interpolate_values(val_a, val_b, factor)
